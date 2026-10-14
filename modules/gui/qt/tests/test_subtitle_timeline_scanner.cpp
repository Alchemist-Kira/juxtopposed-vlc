// SPDX-License-Identifier: GPL-2.0-or-later
#include "config.h"
#include <QTest>
#include <QTemporaryDir>
#include <QFile>
#include <QUrl>
#include <QTcpServer>
#include <QTcpSocket>
#include <QScopeGuard>
#include <future>
#include <cmath>
#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_modules.h>
#include "../../../../lib/libvlc_internal.h"
#include "../player/subtitle_timeline_scanner.hpp"

class SubtitleTimelineScannerTest : public QObject
{
    Q_OBJECT
    libvlc_instance_t *m_vlc = nullptr;
    QTemporaryDir m_dir;

    SubtitleTimelineSource source(const QString& name = QStringLiteral("cues.srt")) {
        SubtitleTimelineSource source;
        source.uri = QUrl::fromLocalFile(m_dir.filePath(name)).toEncoded();
        source.demux = "subtitle";
        source.duration = VLC_TICK_FROM_SEC(10);
        source.deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(10);
        return source;
    }
    SubtitleTimelineScan scan(const SubtitleTimelineSource& source, bool killed = false) {
        auto *interrupt = vlc_interrupt_create();
        if (killed) vlc_interrupt_kill(interrupt);
        auto result = scanSubtitleTimeline(VLC_OBJECT(m_vlc->p_libvlc_int), source, interrupt);
        vlc_interrupt_destroy(interrupt);
        return result;
    }
    void check(const SubtitleTimelineCue& cue, double start, double stop) {
        QVERIFY(std::abs(cue.start / double(CLOCK_FREQ) - start) < .001);
        QVERIFY(std::abs(cue.stop / double(CLOCK_FREQ) - stop) < .001);
    }
private slots:
    void initTestCase() {
        const char *args[] = {"--ignore-config", "--no-media-library", "--quiet"};
        m_vlc = libvlc_new(3, args);
        QVERIFY(m_vlc != nullptr);
        QVERIFY(m_dir.isValid());
        QFile file(m_dir.filePath(QStringLiteral("cues.srt")));
        QVERIFY(file.open(QIODevice::WriteOnly));
        const QByteArray data = "1\n00:00:01,000 --> 00:00:02,500\nFirst\n\n"
            "2\n00:00:02,000 --> 00:00:04,000\nOverlap\n\n"
            "3\n00:00:07,000 --> 00:00:08,250\nLater\n";
        QCOMPARE(file.write(data), data.size());
        file.close();
        file.setFileName(m_dir.filePath(QStringLiteral("frames.sub")));
        QVERIFY(file.open(QIODevice::WriteOnly));
        QVERIFY(file.write("{25}{50}First\n{75}{100}Second\n") > 0);
    }
    void cleanupTestCase() { libvlc_release(m_vlc); }
    void readsRealCueIntervalsIncludingOverlaps() {
        auto result = scan(source());
        QCOMPARE(result.status, SubtitleTimelineScan::Complete);
        QCOMPARE(result.cues.size(), 3);
        check(result.cues[0], 1, 2.5);
        check(result.cues[1], 2, 4);
        check(result.cues[2], 7, 8.25);
    }
    void appliesNativeSubtitleRate() {
        auto request = source(); request.subtitleRate = .5f;
        auto result = scan(request);
        QCOMPARE(result.status, SubtitleTimelineScan::Complete);
        QCOMPARE(result.cues.size(), 3);
        check(result.cues[0], .5, 1.25);
        check(result.cues[2], 3.5, 4.125);
    }
    void usesOriginalFrameRateForFrameBasedSubtitles() {
        auto request = source(QStringLiteral("frames.sub")); request.originalFPS = 25;
        auto result = scan(request);
        QCOMPARE(result.status, SubtitleTimelineScan::Complete);
        QCOMPARE(result.cues.size(), 2);
        check(result.cues[0], 1, 2);
        check(result.cues[1], 3, 4);
    }
    void missingTrackDoesNotInventCues() {
        auto request = source(); request.subtitleIndex = 1;
        auto result = scan(request);
        QCOMPARE(result.status, SubtitleTimelineScan::TrackMissing);
        QVERIFY(result.cues.isEmpty());
    }
    void missingSourceFailsCleanly() {
        auto result = scan(source(QStringLiteral("missing.srt")));
        QCOMPARE(result.status, SubtitleTimelineScan::Failed);
        QVERIFY(result.cues.isEmpty());
    }
    void boundedCueCountIsReportedAsIncomplete() {
        auto request = source(); request.maximumCues = 1;
        auto result = scan(request);
        QCOMPARE(result.status, SubtitleTimelineScan::LimitReached);
        QCOMPARE(result.cues.size(), 1);
    }
    void expiredDeadlineDoesNotReadTheSource() {
        auto request = source(); request.deadline = vlc_tick_now() - 1;
        auto result = scan(request);
        QCOMPARE(result.status, SubtitleTimelineScan::LimitReached);
        QVERIFY(result.cues.isEmpty());
    }
    void alreadyCancelledDoesNotReadTheSource() {
        auto result = scan(source(), true);
        QCOMPARE(result.status, SubtitleTimelineScan::Cancelled);
        QVERIFY(result.cues.isEmpty());
    }
    void cancelsAnActiveBlockedRead() {
        if (!module_exists("https") && !module_exists("http")) QSKIP("HTTP access unavailable");
        QTcpServer server;
        QVERIFY(server.listen(QHostAddress::LocalHost));
        auto request = source();
        request.uri = QStringLiteral("http://127.0.0.1:%1/cues.srt").arg(server.serverPort()).toUtf8();
        auto *interrupt = vlc_interrupt_create();
        auto future = std::async(std::launch::async, [this, request, interrupt] {
            return scanSubtitleTimeline(VLC_OBJECT(m_vlc->p_libvlc_int), request, interrupt);
        });
        QTcpSocket *socket = nullptr;
        const auto cleanup = qScopeGuard([&] {
            vlc_interrupt_kill(interrupt);
            if (socket) socket->abort();
            server.close();
            if (future.valid()) future.wait();
            vlc_interrupt_destroy(interrupt);
        });
        QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 3000);
        socket = server.nextPendingConnection();
        socket->write("HTTP/1.1 200 OK\r\nContent-Length: 1000000\r\nContent-Type: application/x-subrip\r\n\r\n");
        socket->flush();
        QTest::qWait(100);
        QVERIFY(future.wait_for(std::chrono::milliseconds(0)) == std::future_status::timeout);
        vlc_interrupt_kill(interrupt);
        QVERIFY(future.wait_for(std::chrono::seconds(3)) == std::future_status::ready);
        QCOMPARE(future.get().status, SubtitleTimelineScan::Cancelled);
    }
};

QTEST_GUILESS_MAIN(SubtitleTimelineScannerTest)
#include "test_subtitle_timeline_scanner.moc"
