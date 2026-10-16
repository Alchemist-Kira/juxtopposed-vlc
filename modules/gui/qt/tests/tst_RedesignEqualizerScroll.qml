// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls.Basic as C
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedEqualizerScroll"
    width: 900; height: 600
    visible: true; when: windowShown
    QtObject {
        id: store
        property int revision: 0
        property int edits: 0
        function value(name) { return name === "equalizer-preamp" ? 12 : true }
        function equalizerBands() { return Array(10).fill(0) }
        function stage(name, value) { edits++; return true }
        function setEqualizerBand(index, gain) { edits++; return true }
    }
    property var equalizer: null
    Component { id: factory; RedesignEqualizer { backend: store; expanded: true } }
    C.ScrollView {
        id: outer
        x: 20; y: 20; width: equalizer && !equalizer.compact ? 832 : 400; height: 400
        contentWidth: availableWidth
        Column {
            width: outer.availableWidth
            Item { width: 1; height: 100 }
            Item { id: slot; width: parent.width; height: equalizer ? equalizer.implicitHeight : 0 }
            Item { width: 1; height: 600 }
        }
    }
    function init() {
        failOnWarning(/.?/)
        testCase.forceActiveFocus(); store.edits = 0
        outer.contentItem.contentY = 0
        mouseMove(testCase, 899, 599); wait(20)
    }
    function createEqualizer(compact) {
        equalizer = factory.createObject(slot, {compact: compact, x: 24, width: compact ? 352 : 784})
        verify(equalizer); wait(20)
    }
    function cleanup() {
        if (equalizer) equalizer.destroy()
        equalizer = null; wait(20)
    }
    function test_verticalWheelScrollsSettingsWithoutChangingGains_data() {
        return [{tag: "player", compact: true}, {tag: "global", compact: false},
                {tag: "player-diagonal", compact: true, dx: -15}, {tag: "global-diagonal", compact: false, dx: -15}]
    }
    function test_verticalWheelScrollsSettingsWithoutChangingGains(data) {
        createEqualizer(data.compact)
        mouseWheel(equalizer, 200, 160, data.dx || 0, -120)
        tryVerify(() => outer.contentItem.contentY > 0)
        compare(store.edits, 0)
    }
    function test_horizontalWheelScrollsBandsWithoutMovingSettings() {
        createEqualizer(true)
        const inner = findChild(equalizer, "equalizerScroll")
        mouseWheel(equalizer, 200, 160, -120, 0)
        tryVerify(() => inner.contentItem.contentX > 0)
        compare(outer.contentItem.contentY, 0); compare(store.edits, 0)
        mouseWheel(equalizer, 200, 160, 120, 0)
        tryCompare(inner.contentItem, "contentX", 0)
    }
}
