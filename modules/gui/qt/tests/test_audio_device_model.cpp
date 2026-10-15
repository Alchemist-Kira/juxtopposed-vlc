// SPDX-License-Identifier: GPL-2.0-or-later
#include <QTest>
#include <QSignalSpy>
#include <QAbstractItemModelTester>
#include "util/audio_device_model.hpp"
#include <vlc_player.h>
#include <vlc_aout.h>

// A controlled audio-output snapshot; the real model and queued listener are tested.
static audio_output_t firstOutput{}, secondOutput{};
static audio_output_t *output;
static QByteArrayList ids, names;
static QByteArray current;
static const vlc_player_aout_cbs *callbacks;
static void *callbackData;
static int holds;

extern "C" {
void vlc_player_Lock(vlc_player_t *) {}
void vlc_player_Unlock(vlc_player_t *) {}
audio_output_t *vlc_player_aout_Hold(vlc_player_t *) {
    if (output) ++holds;
    return output;
}
void aout_Release(audio_output_t *) { --holds; }
vlc_player_aout_listener_id *vlc_player_aout_AddListener(vlc_player_t *,
        const vlc_player_aout_cbs *cbs, void *data) {
    callbacks = cbs; callbackData = data;
    return reinterpret_cast<vlc_player_aout_listener_id *>(data);
}
void vlc_player_aout_RemoveListener(vlc_player_t *, vlc_player_aout_listener_id *) {
    callbacks = nullptr; callbackData = nullptr;
}
int aout_DevicesList(audio_output_t *, char ***outIds, char ***outNames) {
    *outIds = static_cast<char **>(calloc(ids.size(), sizeof(char *)));
    *outNames = static_cast<char **>(calloc(names.size(), sizeof(char *)));
    for (qsizetype i = 0; i < ids.size(); ++i) {
        (*outIds)[i] = strdup(ids[i].constData());
        (*outNames)[i] = strdup(names[i].constData());
    }
    return ids.size();
}
char *aout_DeviceGet(audio_output_t *) { return current.isEmpty() ? nullptr : strdup(current.constData()); }
int aout_DeviceSet(audio_output_t *, const char *id) {
    current = id;
    callbacks->on_device_changed(output, id, callbackData);
    return 0;
}
}

class TestAudioDeviceModel : public QObject {
    Q_OBJECT
private slots:
    void init() {
        output = &firstOutput;
        ids = {"", "100", "200"}; names = {"Default", "Speakers", "Headphones"};
        current = "200"; holds = 0;
    }
    void cleanup() { QCOMPARE(holds, 0); QVERIFY(!callbacks); }
    void initialSelectionAndUnchangedRefresh() {
        AudioDeviceModel model(nullptr);
        QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
        QCOMPARE(model.rowCount(), 3);
        QVERIFY(model.data(model.index(2), Qt::CheckStateRole).toBool());
        QSignalSpy reset(&model, &QAbstractItemModel::modelReset);
        model.refresh();
        QCOMPARE(reset.count(), 0); QCOMPARE(holds, 1);
    }
    void hotplugAndOutputReplacement() {
        AudioDeviceModel model(nullptr);
        QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
        QSignalSpy reset(&model, &QAbstractItemModel::modelReset);
        ids.append("300"); names.append("Bluetooth"); current = "300";
        model.refresh();
        QCOMPARE(reset.count(), 1); QCOMPARE(model.rowCount(), 4);
        QVERIFY(model.data(model.index(3), Qt::CheckStateRole).toBool());
        ids.removeAt(2); names.removeAt(2); current = "";
        model.refresh();
        QCOMPARE(reset.count(), 2); QCOMPARE(model.rowCount(), 3);
        QVERIFY(model.data(model.index(0), Qt::CheckStateRole).toBool());
        output = &secondOutput;
        model.refresh(); QCOMPARE(reset.count(), 3); QCOMPARE(holds, 1);
        output = nullptr;
        model.refresh(); QCOMPARE(model.rowCount(), 0); QCOMPARE(holds, 0);
    }
    void queuedEventCannotOverwriteCurrentDevice() {
        AudioDeviceModel model(nullptr);
        current = "100";
        callbacks->on_device_changed(output, "200", callbackData);
        QCoreApplication::sendPostedEvents(nullptr, QEvent::MetaCall);
        QVERIFY(model.data(model.index(1), Qt::CheckStateRole).toBool());
        QVERIFY(!model.data(model.index(2), Qt::CheckStateRole).toBool());
    }
    void selectingDeviceUpdatesTheCheckmark() {
        AudioDeviceModel model(nullptr);
        QVERIFY(model.setData(model.index(1), true, Qt::CheckStateRole));
        QCoreApplication::sendPostedEvents(nullptr, QEvent::MetaCall);
        QCOMPARE(current, QByteArray("100"));
        QVERIFY(model.data(model.index(1), Qt::CheckStateRole).toBool());
    }
};
QTEST_GUILESS_MAIN(TestAudioDeviceModel)
#include "test_audio_device_model.moc"
