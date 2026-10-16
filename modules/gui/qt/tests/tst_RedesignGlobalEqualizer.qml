// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedGlobalEqualizer"
    width: 850; height: 700
    visible: true; when: windowShown
    RedesignPreferencesCatalog { id: catalog }
    QtObject {
        id: store
        property int revision: 0
        property var values: ({})
        property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        function value(name) {
            if (name === "redesign-equalizer-preset") return values.enabled ? values.preset || "custom" : ""
            if (name === "equalizer-preset") return values.preset
            if (name === "equalizer-vlcfreqs") return true
            if (name === "equalizer-preamp") return values.preamp
            return values.enabled
        }
        function describe(name) {
            const choices = [{label: "None", value: ""}, {label: "Flat", value: "flat", curve: Array(10).fill(0)},
                             {label: "Rock", value: "rock", curve: Array(10).fill(4)}]
            if (name === "redesign-equalizer-preset" && values.preset === "") choices.splice(1, 0, {label: "Custom", value: "custom", curve: gains})
            return {kind: "string", choices: choices}
        }
        function refresh() { revision++ }
        function stage(name, value) {
            // Changes are published through revision, as in the C++ backend.
            if (name === "redesign-equalizer-preset") {
                values.enabled = value !== ""
                if (value && value !== "custom") values.preset = value
            } else if (name === "equalizer-preamp") values.preamp = value
            else if (name === "filter:audio-filter:equalizer") values.enabled = value
            revision++
            return true
        }
        function equalizerBands() { return gains }
        function setEqualizerBand(index, gain) {
            const next = gains.slice(); next[index] = gain; gains = next
            values.preset = ""; values.enabled = true; revision++
            return true
        }
    }
    RedesignPreferenceRow {
        id: row
        x: 24; y: 20; width: 784
        readonly property var entry: catalog.sections.audio.find(section => section.title === "Effects").rows.find(entry => entry[1] === "Equalizer preset")
        backend: store; optionName: entry[0]; label: entry[1]; presentation: entry[2]
    }
    function item(name) { return findChild(row, name) }
    function init() {
        failOnWarning(/.?/)
        testCase.forceActiveFocus()
        store.values = {enabled: false, preset: "flat", preamp: 12}
        store.gains = Array(10).fill(0); store.revision++
        if (item("equalizerValue_0").visible) item("equalizerExpander").clicked()
        mouseMove(testCase, 840, 690); wait(20)
    }
    function test_disabledFilterShowsNoneAndChoosingPresetEnablesIt() {
        const field = item("preferenceChoiceEditor")
        compare(field.displayText, "None")
        verify(field.showCurvePreviews)
        mouseClick(field); keyClick(Qt.Key_Home); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
        verify(store.values.enabled); compare(field.displayText, "Flat")
        mouseClick(field); keyClick(Qt.Key_Home); keyClick(Qt.Key_Return)
        verify(!store.values.enabled); compare(field.displayText, "None")
        compare(store.values.preset, "flat")
    }
    function test_bandEditsRefreshCustomChoiceAndNoneKeepsCustomValues() {
        item("equalizerExpander").clicked(); wait(20)
        const field = item("equalizerValue_1")
        field.text = "6.2"; field.editingFinished()
        verify(store.values.enabled); compare(store.gains[0], 6.2)
        const choice = item("preferenceChoiceEditor")
        compare(choice.displayText, "Custom")
        mouseClick(choice); keyClick(Qt.Key_Home); keyClick(Qt.Key_Return)
        compare(choice.displayText, "None"); verify(!store.values.enabled)
        compare(store.gains[0], 6.2)
        store.stage("filter:audio-filter:equalizer", true)
        compare(choice.displayText, "Custom")
    }
    function test_preampEditEnablesTheFilterLikeBandEdits() {
        item("equalizerExpander").clicked(); wait(20)
        const field = item("equalizerValue_0")
        field.text = "3.5"; field.editingFinished()
        compare(store.values.preamp, 3.5); verify(store.values.enabled)
        compare(item("preferenceChoiceEditor").displayText, "Flat")
    }
}
