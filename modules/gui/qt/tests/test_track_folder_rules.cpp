// SPDX-License-Identifier: GPL-2.0-or-later
#include <QTest>
#include "../../../misc/medialibrary/track_rules.hpp"

namespace Rules = vlc::medialibrary::trackrules;
class TestTrackFolderRules : public QObject
{
    Q_OBJECT
private slots:
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
    void codecRoundTrip()
    {
        const std::vector<Rules::Pair> original{{"Show_S01E01.mp4",u8"/字幕/a: & #/Show_S01E01.ja.srt"}};
        std::vector<Rules::Pair> result;
        QVERIFY(Rules::decode(Rules::encode(original),result)); QCOMPARE(result.size(),original.size());
        QCOMPARE(result[0].media,original[0].media); QCOMPARE(result[0].track,original[0].track);
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
};
QTEST_GUILESS_MAIN(TestTrackFolderRules)
#include "test_track_folder_rules.moc"
