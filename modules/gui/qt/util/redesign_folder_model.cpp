// SPDX-License-Identifier: GPL-2.0-or-later
#include "redesign_folder_model.hpp"
#include <QTimer>
#include <QDir>
#include <QDateTime>
#include <QThreadPool>
#include <algorithm>

RedesignFolderModel::RedesignFolderModel(QObject* parent)
    : QAbstractListModel(parent)
{
    qRegisterMetaType<QFileInfoList>();
    m_results = std::shared_ptr<RedesignFolderScanResult>(new RedesignFolderScanResult,
        [](RedesignFolderScanResult* result) { result->deleteLater(); });
    connect(m_results.get(), &RedesignFolderScanResult::ready, this,
        [this](quint64 serial, const QFileInfoList& entries) {
            if (serial == m_serial)
                replaceEntries(entries);
        });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this,
        &RedesignFolderModel::scheduleRefresh);
}

void RedesignFolderModel::setFolder(const QUrl& folder)
{
    QUrl normalized = folder;
    if (folder.scheme().isEmpty()) {
        QString path = folder.path();
        if (!folder.host().isEmpty())
            path.prepend("//" + folder.host());
        if (QDir::isAbsolutePath(path))
            normalized = QUrl::fromLocalFile(path);
    }
#ifdef Q_OS_WIN
    else if (folder.scheme().size() == 1) {
        const QString path = folder.scheme() + ":" + folder.path();
        if (QDir::isAbsolutePath(path))
            normalized = QUrl::fromLocalFile(path);
    }
#endif
    if (m_folder == normalized)
        return;
    m_folder = normalized;
    ++m_folderSerial;
    m_artwork.clear();
    m_artworkRequested.clear();
    const auto watched = m_watcher.directories();
    if (!watched.isEmpty())
        m_watcher.removePaths(watched);
    if (m_folder.isLocalFile() && QFileInfo(m_folder.toLocalFile()).isDir())
        m_watcher.addPath(m_folder.toLocalFile());
    replaceEntries({});
    scheduleRefresh();
    emit folderChanged();
}

void RedesignFolderModel::setNameFilters(const QStringList& filters)
{
    if (filters == nameFilters())
        return;
    m_nameFilters = filters;
    scheduleRefresh();
    emit nameFiltersChanged();
}

void RedesignFolderModel::setSortReversed(bool reversed)
{
    if (m_sortReversed == reversed)
        return;
    m_sortReversed = reversed;
    scheduleRefresh();
    emit sortReversedChanged();
}

void RedesignFolderModel::setSortCriteria(const QString& criteria)
{
    if (criteria != "title" && criteria != "insertion" && criteria != "uri")
        return;
    if (m_sortCriteria == criteria) return;
    m_sortCriteria = criteria;
    scheduleRefresh();
    emit sortCriteriaChanged();
}

int RedesignFolderModel::directoryCount() const
{
    return std::count_if(m_entries.cbegin(), m_entries.cend(),
                         [](const QFileInfo& file) { return file.isDir(); });
}

void RedesignFolderModel::setSearchPattern(const QString& pattern)
{
    if (m_searchPattern == pattern)
        return;
    m_searchPattern = pattern;
    scheduleRefresh();
    emit searchPatternChanged();
}

int RedesignFolderModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : count();
}

QHash<int, QByteArray> RedesignFolderModel::roleNames() const
{
    return {{FileName, "fileName"}, {FileUrl, "fileUrl"}, {FileIsDir, "fileIsDir"}, {Thumbnail, "thumbnail"}};
}

QVariant RedesignFolderModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.column() != 0 || index.row() < 0 || index.row() >= count())
        return {};
    const auto& file = m_entries.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case FileName: return file.fileName();
    case FileUrl: return QUrl::fromLocalFile(file.absoluteFilePath());
    case FileIsDir: return file.isDir();
    case Thumbnail: {
        if (file.isDir()) return QString {};
        const auto url = QUrl::fromLocalFile(file.absoluteFilePath());
        if (!m_artworkRequested.contains(url)) {
            m_artworkRequested.insert(url);
            auto self = const_cast<RedesignFolderModel*>(this);
            QTimer::singleShot(0, self, [self, url, serial = m_folderSerial] {
                if (serial == self->m_folderSerial)
                    emit self->artworkRequested(url);
            });
        }
        return m_artwork.value(url);
    }
    default: return {};
    }
}

void RedesignFolderModel::setArtwork(const QUrl& url, const QString& artwork)
{
    // Results are tied to the requested file, never to a row that may have moved.
    if (!m_artworkRequested.contains(url) || m_artwork.value(url) == artwork)
        return;
    m_artwork.insert(url, artwork);
    const auto row = m_rowsByUrl.value(url, -1);
    if (row >= 0)
        emit dataChanged(index(row), index(row), {Thumbnail});
}

QVariant RedesignFolderModel::get(int row, const QString& role) const
{
    const auto roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        if (QString::fromLatin1(it.value()) == role)
            return data(index(row, 0), it.key());
    return {};
}

void RedesignFolderModel::scheduleRefresh()
{
    ++m_serial;
    if (m_refreshPending)
        return;
    m_refreshPending = true;
    QTimer::singleShot(0, this, [this] {
        m_refreshPending = false;
        scan();
    });
}

void RedesignFolderModel::scan()
{
    const auto results = m_results;
    const auto folder = m_folder;
    const auto filters = m_nameFilters;
    const auto serial = m_serial;
    const auto reversed = m_sortReversed;
    const auto sort = m_sortCriteria;
    const auto search = m_searchPattern;
    QThreadPool::globalInstance()->start([results, folder, filters, serial, reversed, sort, search] {
        QFileInfoList entries;
        if (folder.isLocalFile()) {
            QDir directory(folder.toLocalFile());
            entries = directory.entryInfoList(filters,
                QDir::AllEntries | QDir::AllDirs | QDir::Readable | QDir::NoDotAndDotDot,
                QDir::NoSort);
        }
        if (!search.isEmpty())
            entries.erase(std::remove_if(entries.begin(), entries.end(), [&search](const QFileInfo& file) {
                return !file.fileName().contains(search, Qt::CaseInsensitive);
            }), entries.end());
        std::sort(entries.begin(), entries.end(), [&sort, reversed](const QFileInfo& a, const QFileInfo& b) {
            if (a.isDir() != b.isDir()) return a.isDir();
            int primary;
            if (sort == "insertion") {
                const auto av = a.lastModified();
                const auto bv = b.lastModified();
                primary = av < bv ? -1 : av > bv ? 1 : 0;
            } else if (sort == "uri") {
                primary = QUrl::fromLocalFile(a.absoluteFilePath()).toEncoded().compare(
                    QUrl::fromLocalFile(b.absoluteFilePath()).toEncoded());
            } else primary = QString::compare(a.fileName(), b.fileName(), Qt::CaseInsensitive);
            if (primary) return reversed ? primary > 0 : primary < 0;
            return a.fileName() < b.fileName();
        });
        emit results->ready(serial, entries);
    });
}

void RedesignFolderModel::replaceEntries(const QFileInfoList& entries)
{
    const int oldCount = count();
    const int oldDirectoryCount = directoryCount();
    beginResetModel();
    m_entries = entries;
    m_rowsByUrl.clear();
    for (int row = 0; row < m_entries.size(); ++row)
        if (!m_entries[row].isDir())
            m_rowsByUrl.insert(QUrl::fromLocalFile(m_entries[row].absoluteFilePath()), row);
    endResetModel();
    if (oldCount != count() || oldDirectoryCount != directoryCount())
        emit countChanged();
}
