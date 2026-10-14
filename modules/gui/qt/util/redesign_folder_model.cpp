// SPDX-License-Identifier: GPL-2.0-or-later
#include "redesign_folder_model.hpp"
#include <QTimer>
#include <QDir>
#include <QThreadPool>

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
    if (m_folder == folder)
        return;
    m_folder = folder;
    const auto watched = m_watcher.directories();
    if (!watched.isEmpty())
        m_watcher.removePaths(watched);
    if (folder.isLocalFile() && QFileInfo(folder.toLocalFile()).isDir())
        m_watcher.addPath(folder.toLocalFile());
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

int RedesignFolderModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : count();
}

QHash<int, QByteArray> RedesignFolderModel::roleNames() const
{
    return {{FileName, "fileName"}, {FileUrl, "fileUrl"}, {FileIsDir, "fileIsDir"}};
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
    default: return {};
    }
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
    QThreadPool::globalInstance()->start([results, folder, filters, serial, reversed] {
        QFileInfoList entries;
        if (folder.isLocalFile()) {
            QDir directory(folder.toLocalFile());
            entries = directory.entryInfoList(filters,
                QDir::AllEntries | QDir::AllDirs | QDir::Readable | QDir::NoDotAndDotDot,
                QDir::Name | QDir::DirsFirst | QDir::IgnoreCase | (reversed ? QDir::Reversed : QDir::SortFlag(0)));
        }
        emit results->ready(serial, entries);
    });
}

void RedesignFolderModel::replaceEntries(const QFileInfoList& entries)
{
    const int oldCount = count();
    beginResetModel();
    m_entries = entries;
    endResetModel();
    if (oldCount != count())
        emit countChanged();
}
