// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include "util/redesign_folder_model.hpp"

class TestRedesignFolderModel : public QObject
{
    Q_OBJECT
    static void touch(const QString& path) {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
    }
private slots:
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
