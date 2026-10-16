// SPDX-License-Identifier: GPL-2.0-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include <QTest>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QUrl>
#include <vlc_common.h>
#include <vlc_media_library.h>
#include "../../../misc/medialibrary/track_rules.hpp"
#include "../../../misc/medialibrary/track_rule_store.hpp"
#include "../../../misc/medialibrary/library_storage.hpp"
#ifdef _WIN32
# include <windows.h>
#endif

namespace Rules = vlc::medialibrary::trackrules;
class TestTrackFolderRules : public QObject
{
    Q_OBJECT
private slots:
    void windowsLibraryStorage()
    {
        namespace Storage = vlc::medialibrary;
        QVERIFY(Storage::isWslStorage("\\\\wsl.localhost\\Ubuntu\\home\\user\\vlc\\portable"));
        QVERIFY(Storage::isWslStorage("//WSL$/Ubuntu/home/user/vlc/portable"));
        QVERIFY(Storage::isWslStorage("\\\\?\\UNC\\wsl.localhost\\Ubuntu\\home\\user"));
        QVERIFY(!Storage::isWslStorage("//nas/media/vlc/portable"));
        QVERIFY(!Storage::isWslStorage("C:/vlc/portable"));
        QVERIFY(!Storage::isWslStorage("//wsl.localhost"));
        const auto first = Storage::localLibraryStorage("//wsl.localhost/Ubuntu/home/user/vlc/portable", "C:/Local");
        QVERIFY(first.find("C:/Local/vlc/wsl-libraries/") == 0);
        QCOMPARE(first, Storage::localLibraryStorage("\\\\wsl.localhost\\Ubuntu\\home\\user\\vlc\\portable\\", "C:\\Local\\"));
        QCOMPARE(first, Storage::localLibraryStorage("//WSL$/UBUNTU/home/user/vlc/portable", "C:/Local"));
        QVERIFY(first != Storage::localLibraryStorage("//wsl.localhost/Ubuntu/home/user/other/portable", "C:/Local"));
        QVERIFY(Storage::localLibraryStorage("//wsl.localhost/Ubuntu/home/user", "//wsl.localhost/Ubuntu/cache").empty());
    }
    void futureNames_data()
    {
        QTest::addColumn<QString>("sample"); QTest::addColumn<QString>("track");
        QTest::addColumn<QString>("media"); QTest::addColumn<QString>("expected");
        QTest::newRow("episode") << "The_Wand_S01E01.mp4" << "/captions/The_Wand_S01E01.en.srt"
            << "The_Wand_S01E02.mkv" << "/captions/The_Wand_S01E02.en.srt";
        QTest::newRow("compact-case") << "The_Wand_S01E01.mp4" << "/captions/thewand_s01e01.en.srt"
            << "thewand.s01e09.2160p.mkv" << "/captions/thewand_s01e09.en.srt";
        QTest::newRow("cross-season") << "The_Wand_S01E01.mp4" << "/captions/The_Wand_S01E01.en.srt"
            << "The_Wand_S02E12.mp4" << "/captions/The_Wand_S02E12.en.srt";
        QTest::newRow("parent-folder") << "The_Wand_S01E01.mp4" << "/captions/The_Wand_S01E01/English.srt"
            << "The_Wand_S01E03.mp4" << "/captions/The_Wand_S01E03/English.srt";
        QTest::newRow("multiple-markers") << "The_Wand_S01E01.mp4" << "/captions/The_Wand_S01E01/The_Wand_S01E01.en.srt"
            << "The_Wand_S02E03.mp4" << "/captions/The_Wand_S02E03/The_Wand_S02E03.en.srt";
        QTest::newRow("mapped-title") << "The_Wand_S01E01.mp4" << "/captions/Another_Title_1x01.fr.srt"
            << "The_Wand_S01E02.mp4" << "/captions/Another_Title_1x02.fr.srt";
        QTest::newRow("unicode") << QString::fromUtf8("魔法_S01E01.mp4") << QString::fromUtf8("/字幕/魔法_S01E01.ja.srt")
            << QString::fromUtf8("魔法_S01E02.mp4") << QString::fromUtf8("/字幕/魔法_S01E02.ja.srt");
        QTest::newRow("padding-growth") << "Show_S01E01.mp4" << "/subs/Show_S01E01.idx"
            << "Show_S01E100.mp4" << "/subs/Show_S01E100.idx";
        QTest::newRow("other-show") << "The_Wand_S01E01.mp4" << "/captions/The_Wand_S01E01.en.srt"
            << "Another_Show_S01E02.mp4" << "";
        QTest::newRow("manual-exception") << "The_Wand_S01E01.mp4" << "/captions/The_Wand_S01E04.en.srt"
            << "The_Wand_S01E02.mp4" << "";
        QTest::newRow("generic-track") << "The_Wand_S01E01.mp4" << "/captions/English.srt"
            << "The_Wand_S01E02.mp4" << "";
        QTest::newRow("movie") << "First Film.mp4" << "/captions/First Film.en.srt"
            << "Second Film.mkv" << "/captions/Second Film.en.srt";
        QTest::newRow("not-resolution") << "Film.1920x1080.mp4" << "/captions/Film.1920x1080.en.srt"
            << "Other.1920x1080.mp4" << "/captions/Other.1920x1080.en.srt";
    }
    void futureNames()
    {
        QFETCH(QString,sample); QFETCH(QString,track); QFETCH(QString,media); QFETCH(QString,expected);
        const auto result = Rules::expected({sample.toStdString(),track.toStdString()},media.toStdString());
        QCOMPARE(result ? QString::fromStdString(*result) : QString(),expected);
    }
    void distinctVariants()
    {
        const auto result = Rules::distinct({{"Show_S01E01.mp4","/subs/Show_S01E01.en.srt"},
            {"Show_S01E02.mp4","/subs/Show_S01E02.en.srt"},
            {"Show_S01E01.mp4","/subs/Show_S01E01.en.forced.srt"},
            {"Show_S01E01.mp4","/subs/Show_S01E01.fr.srt"},
            {"Show_S01E01.mp4","/subs/unrelated.srt"}});
        QCOMPARE(result.size(),size_t(3));
    }
    void profilePathIsNotAnEpisodeTemplate()
    {
        const Rules::Pair pair{"Show_S01E01.mp4","/profile_S01E01/subtitles/captions.srt","/profile_S01E01/subtitles"};
        QVERIFY(!Rules::expected(pair,"Show_S01E02.mp4"));
        const Rules::Pair relative{"Show_S01E01.mp4","Show_S01E01/English.srt","Show_S01E01"};
        QVERIFY(Rules::expected(relative,"Show_S01E02.mp4"));
    }
    void codecRoundTrip()
    {
        const std::vector<Rules::Pair> original{{"Show_S01E01.mp4",u8"/字幕/a: & #/Show_S01E01.ja.srt"}};
        std::vector<Rules::Pair> result;
        QVERIFY(Rules::decode(Rules::encode(original),result)); QCOMPARE(result.size(),original.size());
        QCOMPARE(result[0].media,original[0].media); QCOMPARE(result[0].track,original[0].track);
        QCOMPARE(result[0].source,Rules::parent(original[0].track));
    }
    void malformedDefinitions_data()
    {
        QTest::addColumn<QByteArray>("text");
        QTest::newRow("version") << QByteArray("2|");
        QTest::newRow("missing-track") << QByteArray("1|4:show");
        QTest::newRow("length") << QByteArray("1|99999999999999999999999999:a");
        QTest::newRow("truncated") << QByteArray("1|999:a");
        QTest::newRow("nul") << QByteArray("1|3:a\0b",8);
        QTest::newRow("oversized") << (QByteArray("1|")+QByteArray(Rules::MaxBytes,'a'));
    }
    void malformedDefinitions()
    {
        QFETCH(QByteArray,text); std::vector<Rules::Pair> result;
        QVERIFY(!Rules::decode(std::string(text.constData(),text.size()),result)); QVERIFY(result.empty());
    }
    void persistentScopeAndRemoval()
    {
        QTemporaryDir directory;
        const auto root=directory.filePath("rules").toStdString();
        const auto a=QUrl::fromLocalFile(directory.filePath("show")).toString(QUrl::FullyEncoded).toStdString();
        const auto b=QUrl::fromLocalFile(directory.filePath("show-extra")).toString(QUrl::FullyEncoded).toStdString();
        vlc::medialibrary::TrackRuleStore store(root);std::string read;
        const auto definition=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.en.srt").toStdString()}});
        QVERIFY(store.read(a,VLC_ML_FILE_TYPE_SUBTITLE,read));QVERIFY(read.empty());
        QVERIFY(!QFileInfo::exists(QString::fromStdString(root)));
        QVERIFY(store.write(a,VLC_ML_FILE_TYPE_SUBTITLE,definition));
        vlc::medialibrary::TrackRuleStore reopened(root);
        QVERIFY(reopened.read(a,VLC_ML_FILE_TYPE_SUBTITLE,read));QCOMPARE(read,definition);
        QVERIFY(reopened.read(b,VLC_ML_FILE_TYPE_SUBTITLE,read));QVERIFY(read.empty());
        QVERIFY(reopened.read(a,VLC_ML_FILE_TYPE_SOUNDTRACK,read));QVERIFY(read.empty());
        const auto dotted=QUrl::fromLocalFile(directory.filePath("show/./")).toString(QUrl::FullyEncoded).toStdString();
        QCOMPARE(store.location(a,VLC_ML_FILE_TYPE_SUBTITLE),store.location(dotted,VLC_ML_FILE_TYPE_SUBTITLE));
        QVERIFY(reopened.write(a,VLC_ML_FILE_TYPE_SUBTITLE,""));
        QVERIFY(reopened.read(a,VLC_ML_FILE_TYPE_SUBTITLE,read));QVERIFY(read.empty());
    }
    void futureFilesAndVariants()
    {
        QTemporaryDir directory;
        const auto english=directory.filePath("Show_S01E02.en.srt"),french=directory.filePath("Show_S01E02.fr.srt");
        for(const auto& path:{english,french}) {QFile file(path);QVERIFY(file.open(QIODevice::WriteOnly));file.write("captions");}
        const auto definition=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.en.srt").toStdString()},
            {"Show_S01E01.mp4",directory.filePath("Show_S01E01.fr.srt").toStdString()}});
        vlc::medialibrary::TrackRuleStore store(directory.filePath("rules").toStdString());
        bool applies=false;std::vector<std::string> paths;
        QVERIFY(store.resolve(definition,"Show_S01E02.mkv",applies,paths));QVERIFY(applies);QCOMPARE(paths.size(),size_t(2));
        QVERIFY(store.resolve(definition,"Show_S01E03.mkv",applies,paths));QVERIFY(applies);QVERIFY(paths.empty());
        QVERIFY(store.resolve(definition,"Other_S01E02.mkv",applies,paths));QVERIFY(!applies);QVERIFY(paths.empty());
        QVERIFY(QFileInfo::exists(english));QVERIFY(QFileInfo::exists(french));
    }
    void ambiguousEquivalentNamesNeedAChoice()
    {
        QTemporaryDir directory;
        const auto a=directory.filePath("show.s01e02.en.srt"),b=directory.filePath("show-s01e02-en.srt");
        QFile first(a);QVERIFY(first.open(QIODevice::WriteOnly));first.write("captions");first.close();
        const auto definition=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.en.srt").toStdString()}});
        vlc::medialibrary::TrackRuleStore store(directory.filePath("rules").toStdString());bool applies;std::vector<std::string> paths;
        QVERIFY(store.resolve(definition,"Show_S01E02.mp4",applies,paths));QCOMPARE(paths.size(),size_t(1));QCOMPARE(paths[0],a.toStdString());
        QFile second(b);QVERIFY(second.open(QIODevice::WriteOnly));second.write("captions");second.close();
        QVERIFY(store.resolve(definition,"Show_S01E02.mp4",applies,paths));QVERIFY(applies);QVERIFY(paths.empty());
    }
    void invalidReplacementKeepsThePreviousRule()
    {
        QTemporaryDir directory;vlc::medialibrary::TrackRuleStore store(directory.filePath("rules").toStdString());
        const auto folder=QUrl::fromLocalFile(directory.path()).toString(QUrl::FullyEncoded).toStdString();
        const auto definition=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.en.srt").toStdString()}});
        QVERIFY(store.write(folder,VLC_ML_FILE_TYPE_SUBTITLE,definition));
        QVERIFY(!store.write(folder,VLC_ML_FILE_TYPE_SUBTITLE,"broken"));
        QVERIFY(!store.write(folder,VLC_ML_FILE_TYPE_SUBTITLE,Rules::encode({{"Show_S01E01.mp4","relative/Show_S01E01.en.srt","/source"}})));
        std::string read;QVERIFY(store.read(folder,VLC_ML_FILE_TYPE_SUBTITLE,read));QCOMPARE(read,definition);
    }
    void copiedScopeAndCorruptRecordsAreRejected()
    {
        QTemporaryDir directory;vlc::medialibrary::TrackRuleStore store(directory.filePath("rules").toStdString());
        const auto a=QUrl::fromLocalFile(directory.filePath("one")).toString(QUrl::FullyEncoded).toStdString();
        const auto b=QUrl::fromLocalFile(directory.filePath("two")).toString(QUrl::FullyEncoded).toStdString();
        const auto definition=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.en.srt").toStdString()}});
        QVERIFY(store.write(a,VLC_ML_FILE_TYPE_SUBTITLE,definition));
        QVERIFY(QFile::copy(QString::fromStdString(store.location(a,VLC_ML_FILE_TYPE_SUBTITLE)),QString::fromStdString(store.location(b,VLC_ML_FILE_TYPE_SUBTITLE))));
        std::string read;QVERIFY(!store.read(b,VLC_ML_FILE_TYPE_SUBTITLE,read));QVERIFY(read.empty());
        QFile file(QString::fromStdString(store.location(a,VLC_ML_FILE_TYPE_SUBTITLE)));QVERIFY(file.open(QIODevice::WriteOnly));file.write("broken");file.close();
        QVERIFY(!store.read(a,VLC_ML_FILE_TYPE_SUBTITLE,read));QVERIFY(read.empty());
        vlc::medialibrary::TrackRuleStore relative("relative");QVERIFY(!relative.write(a,VLC_ML_FILE_TYPE_SUBTITLE,definition));
    }
#ifdef _WIN32
    void windowsScopeUsesFilesystemCasing()
    {
        QTemporaryDir directory;vlc::medialibrary::TrackRuleStore store(directory.filePath("rules").toStdString());
        const auto compare=[&](const QString& left,const QString& right) {
            const auto a=left.toStdWString(),b=right.toStdWString();
            const bool same=CompareStringOrdinal(a.c_str(),-1,b.c_str(),-1,TRUE)==CSTR_EQUAL;
            const auto x=store.location(QUrl::fromLocalFile(left).toString(QUrl::FullyEncoded).toStdString(),VLC_ML_FILE_TYPE_SUBTITLE);
            const auto y=store.location(QUrl::fromLocalFile(right).toString(QUrl::FullyEncoded).toStdString(),VLC_ML_FILE_TYPE_SUBTITLE);
            QCOMPARE(x==y,same);
        };
        compare(QString::fromUtf8("C:/Shows/ΟΣ"),QString::fromUtf8("c:/shows/ος"));
        compare(QString::fromUtf8("C:/Shows/Straße"),QString::fromUtf8("C:/Shows/STRASSE"));
        compare("//OtherPC/Movies","//otherpc/movies");
    }
    void lockedWindowsFileKeepsThePreviousRule()
    {
        QTemporaryDir directory;vlc::medialibrary::TrackRuleStore store(directory.filePath("rules").toStdString());
        const auto folder=QUrl::fromLocalFile(directory.path()).toString(QUrl::FullyEncoded).toStdString();
        const auto a=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.en.srt").toStdString()}});
        const auto b=Rules::encode({{"Show_S01E01.mp4",directory.filePath("Show_S01E01.fr.srt").toStdString()}});
        QVERIFY(store.write(folder,VLC_ML_FILE_TYPE_SUBTITLE,a));
        const auto path=QString::fromStdString(store.location(folder,VLC_ML_FILE_TYPE_SUBTITLE)).toStdWString();
        const auto file=CreateFileW(path.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,0,nullptr);
        QVERIFY(file!=INVALID_HANDLE_VALUE);const bool replaced=store.write(folder,VLC_ML_FILE_TYPE_SUBTITLE,b);CloseHandle(file);
        QVERIFY(!replaced);std::string read;QVERIFY(store.read(folder,VLC_ML_FILE_TYPE_SUBTITLE,read));QCOMPARE(read,a);
    }
#endif
};
QTEST_GUILESS_MAIN(TestTrackFolderRules)
#include "test_track_folder_rules.moc"
