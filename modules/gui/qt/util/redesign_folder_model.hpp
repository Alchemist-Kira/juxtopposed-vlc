// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef VLC_REDESIGN_FOLDER_MODEL_HPP
#define VLC_REDESIGN_FOLDER_MODEL_HPP

#include <QAbstractListModel>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QUrl>
#include <QVector>
#include <memory>

class RedesignFolderScanResult : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
signals:
    void ready(quint64 serial, const QFileInfoList& entries);
};

/** Flat folder contents backed by Qt's asynchronous filesystem watcher. */
class RedesignFolderModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QUrl folder READ folder WRITE setFolder NOTIFY folderChanged FINAL)
    Q_PROPERTY(QStringList nameFilters READ nameFilters WRITE setNameFilters NOTIFY nameFiltersChanged FINAL)
    Q_PROPERTY(bool sortReversed READ sortReversed WRITE setSortReversed NOTIFY sortReversedChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    Q_PROPERTY(int directoryCount READ directoryCount NOTIFY countChanged FINAL)
    Q_PROPERTY(QString searchPattern READ searchPattern WRITE setSearchPattern NOTIFY searchPatternChanged FINAL)
public:
    enum Role { FileName = Qt::UserRole + 1, FileUrl, FileIsDir };
    explicit RedesignFolderModel(QObject* parent = nullptr);
    QUrl folder() const { return m_folder; }
    void setFolder(const QUrl& folder);
    QStringList nameFilters() const { return m_nameFilters; }
    void setNameFilters(const QStringList& filters);
    bool sortReversed() const { return m_sortReversed; }
    void setSortReversed(bool reversed);
    int count() const { return m_entries.size(); }
    int directoryCount() const;
    QString searchPattern() const { return m_searchPattern; }
    void setSearchPattern(const QString& pattern);
    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariant get(int row, const QString& role) const;
signals:
    void folderChanged();
    void nameFiltersChanged();
    void sortReversedChanged();
    void countChanged();
    void searchPatternChanged();
private:
    void scheduleRefresh();
    void scan();
    void replaceEntries(const QFileInfoList& entries);
    QFileSystemWatcher m_watcher;
    std::shared_ptr<RedesignFolderScanResult> m_results;
    QStringList m_nameFilters;
    QUrl m_folder;
    QString m_searchPattern;
    QFileInfoList m_entries;
    quint64 m_serial = 0;
    bool m_sortReversed = false;
    bool m_refreshPending = false;
};
#endif
