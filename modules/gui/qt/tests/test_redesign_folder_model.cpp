// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include "util/redesign_folder_model.hpp"

class TestRedesignFolderModel : public QObject
{
    Q_OBJECT
    static void touch(const QString& path) {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
    }
private slots:
    void artworkIsLazyAndDirectoriesDoNotRequestIt() {
        QTemporaryDir directory;
        QDir dir(directory.path());
        QVERIFY(dir.mkdir("folder"));
        touch(dir.filePath("movie.mp4"));
        RedesignFolderModel model;
        QSignalSpy requested(&model, &RedesignFolderModel::artworkRequested);
        QSignalSpy changed(&model, &RedesignFolderModel::dataChanged);
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        QTRY_COMPARE(model.count(), 2);
        QCOMPARE(requested.count(), 0);
        QVERIFY(model.get(0, "thumbnail").toString().isEmpty());
        QVERIFY(model.get(1, "thumbnail").toString().isEmpty());
        QVERIFY(model.get(1, "thumbnail").toString().isEmpty());
        QTRY_COMPARE(requested.count(), 1);
        const auto url = model.get(1, "fileUrl").toUrl();
        QCOMPARE(requested[0][0].toUrl(), url);
        model.setArtwork(url, QStringLiteral("file:///cached/movie.jpg"));
        QCOMPARE(model.get(1, "thumbnail").toString(), QStringLiteral("file:///cached/movie.jpg"));
        QCOMPARE(changed.count(), 1);
        QCOMPARE(changed[0][2].value<QList<int>>(), QList<int>{RedesignFolderModel::Thumbnail});
    }
    void artworkFollowsFilesAcrossSortAndSearch() {
        QTemporaryDir directory;
        QDir dir(directory.path());
        touch(dir.filePath("a.mp4")); touch(dir.filePath("b.mp4"));
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        QTRY_COMPARE(model.count(), 2);
        const auto a = model.get(0, "fileUrl").toUrl();
        const auto b = model.get(1, "fileUrl").toUrl();
        model.get(0, "thumbnail"); model.get(1, "thumbnail");
        model.setSearchPattern("b");
        QTRY_COMPARE(model.count(), 1);
        model.setArtwork(a, QStringLiteral("a.jpg"));
        model.setArtwork(b, QStringLiteral("b.jpg"));
        QCOMPARE(model.get(0, "thumbnail").toString(), QStringLiteral("b.jpg"));
        model.setSearchPattern(""); model.setSortReversed(true);
        QTRY_COMPARE(model.count(), 2);
        QCOMPARE(model.get(0, "fileName").toString(), QStringLiteral("b.mp4"));
        QCOMPARE(model.get(0, "thumbnail").toString(), QStringLiteral("b.jpg"));
        QCOMPARE(model.get(1, "thumbnail").toString(), QStringLiteral("a.jpg"));
    }
    void oldFolderArtworkCannotReplaceCurrentFiles() {
        QTemporaryDir first, second;
        touch(QDir(first.path()).filePath("movie.mp4"));
        touch(QDir(second.path()).filePath("movie.mp4"));
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(first.path()));
        QTRY_COMPARE(model.count(), 1);
        const auto old = model.get(0, "fileUrl").toUrl();
        model.get(0, "thumbnail");
        model.setFolder(QUrl::fromLocalFile(second.path()));
        QTRY_COMPARE(model.count(), 1);
        model.get(0, "thumbnail");
        model.setArtwork(old, QStringLiteral("old.jpg"));
        QVERIFY(model.get(0, "thumbnail").toString().isEmpty());
        model.setArtwork(model.get(0, "fileUrl").toUrl(), QStringLiteral("current.jpg"));
        QCOMPARE(model.get(0, "thumbnail").toString(), QStringLiteral("current.jpg"));
    }
    void sortDatesAndEncodedUrisKeepDirectoriesFirst() {
        QTemporaryDir directory;
        QDir dir(directory.path());
        QVERIFY(dir.mkdir("folder"));
        touch(dir.filePath("a.mp4"));
        touch(dir.filePath("z.mp4"));
        touch(dir.filePath("é.mp4"));
        for (const auto& pair : QList<QPair<QString, int>>{{"a.mp4",300},{"z.mp4",100},{"é.mp4",200}}) {
            QFile file(dir.filePath(pair.first));
            QVERIFY(file.open(QIODevice::ReadWrite));
            QVERIFY(file.setFileTime(QDateTime::fromSecsSinceEpoch(1600000000 + pair.second), QFileDevice::FileModificationTime));
        }
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        QTRY_COMPARE(model.count(), 4);
        model.setSortCriteria("insertion");
        model.setSortReversed(true);
        QTRY_COMPARE(model.get(2, "fileName").toString(), "é.mp4");
        QCOMPARE(model.get(1, "fileName").toString(), "a.mp4");
        QCOMPARE(model.get(0, "fileName").toString(), "folder");
        model.setSortReversed(false);
        QTRY_COMPARE(model.get(1, "fileName").toString(), "z.mp4");
        model.setSortCriteria("uri");
        QTRY_COMPARE(model.get(1, "fileName").toString(), "é.mp4");
        QCOMPARE(model.get(0, "fileName").toString(), "folder");
        model.setSortReversed(true);
        QTRY_COMPARE(model.get(1, "fileName").toString(), "z.mp4");
        QCOMPARE(model.get(3, "fileName").toString(), "é.mp4");
    }
    void absoluteLibraryPathIsLocal() {
        QTemporaryDir directory;
        touch(QDir(directory.path()).filePath("movie.mp4"));
        RedesignFolderModel model;
        model.setFolder(QUrl(directory.path()));
        QTRY_COMPARE(model.count(), 1);
        QVERIFY(model.folder().isLocalFile());
        QCOMPARE(QFileInfo(model.folder().toLocalFile()), QFileInfo(directory.path()));
        QCOMPARE(QFileInfo(model.get(0, "fileUrl").toUrl().toLocalFile()), QFileInfo(QDir(directory.path()).filePath("movie.mp4")));
    }
    void networkUrlsAreNotLocalPaths() {
        RedesignFolderModel model;
        const QUrl url("https://example.invalid/media");
        model.setFolder(url);
        QCOMPARE(model.folder(), url);
        QVERIFY(!model.folder().isLocalFile());
    }
    void searchKeepsMediaFilters() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        QDir dir(directory.path());
        QVERIFY(dir.mkdir("Alpha Folder"));
        touch(dir.filePath("ALPHA.mp4"));
        touch(dir.filePath("Alpha.txt"));
        touch(dir.filePath("Beta.mp4"));
        RedesignFolderModel model;
        model.setNameFilters({"*.mp4"});
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        QTRY_COMPARE(model.count(), 3);
        QCOMPARE(model.directoryCount(), 1);
        model.setSearchPattern("alpha");
        QTRY_COMPARE(model.count(), 2);
        QCOMPARE(model.get(0, "fileName").toString(), "Alpha Folder");
        QCOMPARE(model.get(1, "fileName").toString(), "ALPHA.mp4");
        model.setSearchPattern("missing");
        QTRY_COMPARE(model.count(), 0);
        QCOMPARE(model.directoryCount(), 0);
        model.setSearchPattern("");
        QTRY_COMPARE(model.count(), 3);
    }
    void unicodeNames() {
        QTemporaryDir directory;
        touch(QDir(directory.path()).filePath(QString::fromUtf8("Épisode 日本語.mp4")));
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        QTRY_COMPARE(model.count(), 1);
        model.setSearchPattern(QString::fromUtf8("éPISODE"));
        QTest::qWait(100);
        QCOMPARE(model.count(), 1);
        QCOMPARE(model.get(0, "fileUrl").toUrl().fileName(), QString::fromUtf8("Épisode 日本語.mp4"));
        model.setSearchPattern(QString::fromUtf8("日本語"));
        QTest::qWait(100);
        QCOMPARE(model.count(), 1);
    }
    void latestFolderAndSearchWin() {
        QTemporaryDir first, second;
        touch(QDir(first.path()).filePath("old.mp4"));
        touch(QDir(second.path()).filePath("current.mp4"));
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(first.path()));
        model.setSearchPattern("old");
        model.setFolder(QUrl::fromLocalFile(second.path()));
        model.setSearchPattern("current");
        QTRY_COMPARE(model.count(), 1);
        QCOMPARE(model.get(0, "fileName").toString(), "current.mp4");
    }
    void watcherAppliesActiveSearch() {
        QTemporaryDir directory;
        QDir dir(directory.path());
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        model.setSearchPattern("match");
        QTest::qWait(100);
        touch(dir.filePath("match.mp4"));
        touch(dir.filePath("other.mp4"));
        QTRY_COMPARE(model.count(), 1);
        QCOMPARE(model.get(0, "fileName").toString(), "match.mp4");
        QVERIFY(QFile::remove(dir.filePath("match.mp4")));
        QTRY_COMPARE(model.count(), 0);
    }
    void directoryCountChangesAtConstantRowCount() {
        QTemporaryDir directory;
        QDir dir(directory.path());
        touch(dir.filePath("entry"));
        RedesignFolderModel model;
        model.setFolder(QUrl::fromLocalFile(directory.path()));
        QTRY_COMPARE(model.count(), 1);
        QCOMPARE(model.directoryCount(), 0);
        QSignalSpy changed(&model, &RedesignFolderModel::countChanged);
        QVERIFY(QFile::remove(dir.filePath("entry")));
        QVERIFY(dir.mkdir("entry"));
        QTRY_COMPARE(model.directoryCount(), 1);
        QCOMPARE(model.count(), 1);
        QVERIFY(changed.count() > 0);
    }
};
QTEST_GUILESS_MAIN(TestRedesignFolderModel)
#include "test_redesign_folder_model.moc"
