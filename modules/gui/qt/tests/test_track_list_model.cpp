// SPDX-License-Identifier: GPL-2.0-or-later
#include <QTest>
#include <QSignalSpy>
#include <QAbstractItemModelTester>
#include <QUrl>
#include "player/input_models.hpp"

struct TestTrackId { QByteArray uri; int references = 0; };
static int references;
static vlc_es_id_t* selected;
static TestTrackId& trackId(vlc_es_id_t* id) { return *reinterpret_cast<TestTrackId*>(id); }
extern "C" {
vlc_es_id_t* vlc_es_id_Hold(vlc_es_id_t* id) { ++trackId(id).references; ++references; return id; }
void vlc_es_id_Release(vlc_es_id_t* id) { --trackId(id).references; --references; }
const char* vlc_es_id_GetSourceUri(vlc_es_id_t* id) { return trackId(id).uri.isEmpty() ? nullptr : trackId(id).uri.constData(); }
enum es_format_category_e vlc_es_id_GetCat(vlc_es_id_t*) { return SPU_ES; }
void vlc_player_Lock(vlc_player_t*) {}
void vlc_player_Unlock(vlc_player_t*) {}
unsigned vlc_player_SelectEsId(vlc_player_t*, vlc_es_id_t* id, enum vlc_player_select_policy) { selected = id; return 1; }
void vlc_player_UnselectEsId(vlc_player_t*, vlc_es_id_t* id) { if (selected == id) selected = nullptr; }
}

class TestTrackListModel : public QObject {
    Q_OBJECT
    static vlc_player_track track(TestTrackId& id, const char* title, bool checked = false) {
        vlc_player_track value{};
        value.es_id = reinterpret_cast<vlc_es_id_t*>(&id); value.name = title; value.selected = checked;
        return value;
    }
private slots:
    void init() { references = 0; selected = nullptr; }
    void cleanup() { QCOMPARE(references, 0); }
    void sourcesAndSelection() {
        TestTrackId embedded{}, external{"file:///C:/Movies/caps%20%26%20captions.srt"};
        TrackListModel model(nullptr);
        QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
        auto first = track(embedded, "English", true), second = track(external, "Track 2");
        model.updateTracks(VLC_PLAYER_LIST_ADDED, &first);
        model.updateTracks(VLC_PLAYER_LIST_ADDED, &second);
        QCOMPARE(model.rowCount(), 2);
        QVERIFY(!model.data(model.index(0), TrackListModel::ExternalRole).toBool());
        QVERIFY(model.data(model.index(1), TrackListModel::ExternalRole).toBool());
        QCOMPARE(model.data(model.index(1), TrackListModel::SourceNameRole).toString(), "caps & captions.srt");
        QCOMPARE(model.data(model.index(1), TrackListModel::SourceUriRole).toUrl(), QUrl(QString::fromUtf8(external.uri)));
        QVERIFY(model.setData(model.index(1), true, Qt::CheckStateRole));
        QCOMPARE(selected, second.es_id);
        model.updateTrackSelection(first.es_id, false); model.updateTrackSelection(second.es_id, true);
        QVERIFY(!model.data(model.index(0), Qt::CheckStateRole).toBool());
        QVERIFY(model.data(model.index(1), Qt::CheckStateRole).toBool());
        model.clear(); model.clear(); QCOMPARE(model.rowCount(), 0);
        QVERIFY(!model.data(QModelIndex()).isValid());
        QVERIFY(!model.setData(QModelIndex(), true, Qt::CheckStateRole));
    }
    void sharedSourcesKeepDistinctLabels() {
        TestTrackId one{"file:///audio/alternate.mka"}, two{"file:///audio/alternate.mka"};
        TrackListModel model(nullptr);
        QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
        auto first = track(one, "English"), second = track(two, "Japanese");
        model.updateTracks(VLC_PLAYER_LIST_ADDED, &first);
        QCOMPARE(model.data(model.index(0), TrackListModel::SourceNameRole).toString(), "alternate.mka");
        QSignalSpy updates(&model, &QAbstractItemModel::dataChanged);
        model.updateTracks(VLC_PLAYER_LIST_ADDED, &second);
        QVERIFY(!updates.isEmpty());
        QCOMPARE(model.data(model.index(0), TrackListModel::SourceNameRole).toString(), "alternate.mka (English)");
        QCOMPARE(model.data(model.index(1), TrackListModel::SourceNameRole).toString(), "alternate.mka (Japanese)");
        second.name = "French"; model.updateTracks(VLC_PLAYER_LIST_UPDATED, &second);
        QCOMPARE(model.data(model.index(1), TrackListModel::SourceNameRole).toString(), "alternate.mka (French)");
        model.updateTracks(VLC_PLAYER_LIST_REMOVED, &second);
        QCOMPARE(model.data(model.index(0), TrackListModel::SourceNameRole).toString(), "alternate.mka");
    }
    void remoteSourcesHideCredentials() {
        TestTrackId id{"https://account:secret@example.test/subtitles/captions%20en.srt"};
        TrackListModel model(nullptr); auto value = track(id, "English");
        model.updateTracks(VLC_PLAYER_LIST_ADDED, &value);
        QCOMPARE(model.data(model.index(0), TrackListModel::SourceNameRole).toString(), "captions en.srt");
        const auto uri = model.data(model.index(0), TrackListModel::SourceUriRole).toUrl();
        QVERIFY(uri.userInfo().isEmpty()); QCOMPARE(uri.host(), "example.test");
    }
};
QTEST_GUILESS_MAIN(TestTrackListModel)
#include "test_track_list_model.moc"
