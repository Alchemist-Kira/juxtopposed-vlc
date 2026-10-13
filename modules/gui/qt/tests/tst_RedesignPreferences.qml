// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedPreferences"
    width: 900; height: 600
    when: windowShown
    visible: true
    QtObject {
        id: store
        property int revision: 0
        property int refreshCount: 0
        property var values: ({resize: true, fastSeek: false, timeout: 1800})
        function value(name) { return values[name] }
        function refresh() { refreshCount++; revision++ }
        function describe(name) {
            if (name === "volumeStep") return {kind: "float", title: "Volume step", choices: []}
            if (name === "device") return {kind: "string", title: "Output device", choices: [{label: "System default", value: ""}, {label: "Headphones", value: "native-headphones"}]}
            return {kind: name === "timeout" ? "integer" : name === "clickPolicy" ? "string" : "bool", title: name, help: "", choices: []}
        }
        function stage(name, value) {
            if (name === "redesign-startup-volume") {
                const number = Number(value)
                if (!String(value).trim().length || !Number.isInteger(number) || number < 0 || number > 300) return false
                value = number
            }
            const next = Object.assign({}, values)
            next[name] = value
            values = next
            revision++
            return true
        }
        function reset(name) { stage(name, name === "timeout" ? 1800 : name === "resize") }
    }
    QtObject {
        id: equalizerStore
        property int revision: 0
        property var gains: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        property real preamp: 12
        function equalizerBands() { return gains }
        function value(name) { return name === "equalizer-preamp" ? preamp : true }
        function stage(name, gain) { preamp = gain; revision++; return true }
        function setEqualizerBand(index, gain) { const next = gains.slice(); next[index] = gain; gains = next; revision++; return true }
    }
    RedesignEqualizer {
        id: equalizer
        x: 0; y: 80; width: 784
        backend: equalizerStore
        visible: false
    }
    RedesignPreferencesCatalog { id: catalog }
    Column {
        width: parent.width
        RedesignPreferenceRow {
            id: resizeRow
            width: parent.width; backend: store; optionName: "resize"
            label: "Resize window to fit video"
            presentation: ({choices: [{label: "Never", value: false}, {label: "Always", value: true}]})
        }
        RedesignPreferenceRow {
            id: seekRow
            width: parent.width; backend: store; optionName: "fastSeek"
            label: "Seek precisely"; presentation: ({inverted: true})
        }
        RedesignPreferenceRow {
            id: delayRow
            width: parent.width; backend: store; optionName: "timeout"
            label: "Hide after"
            presentation: ({editor: "slider", from: 0, to: 10, factor: 0.001, step: 0.1, suffix: " s"})
        }
    }
    RedesignPreferenceRow {
        id: timingTextRow
        y: 160; width: parent.width; backend: store; optionName: "timeout"
        label: "Popup duration"
        presentation: ({factor: 0.001, suffix: " s"})
    }
    RedesignPreferenceRow {
        id: clickPolicyRow
        y: 230; width: parent.width; backend: store; optionName: "clickPolicy"
        label: "Single click on the video"
        presentation: catalog.sections.controls.find(section => section.title === "Mouse").rows[0][2]
    }
    RedesignPreferenceRow {
        id: remotePortRow
        y: 290; width: parent.width; backend: store; optionName: "timeout"
        label: "Port"; presentation: ({enabledWhen: "resize"})
    }
    RedesignStartupVolume {
        id: startupVolume
        y: 350; width: 320
        backend: store
        visible: false
    }
    RedesignPreferenceRow {
        id: deviceRow
        y: 350; width: parent.width
        backend: store; optionName: "device"; label: "Output device"
        presentation: ({dynamicChoices: true})
        visible: false
    }
    RedesignPreferenceRow {
        id: volumeStepRow
        y: 430; width: parent.width
        backend: store; optionName: "volumeStep"; label: "Volume step"
        presentation: ({factor: 100 / 256, decimals: 1, suffix: "%"})
        visible: false
    }
    RedesignShortcutEditor {
        id: shortcutEditor
        parent: testCase
        shortcuts: [{name: "key-toggle-fullscreen", globalName: "global-key-toggle-fullscreen", title: "Toggle fullscreen", group: "Basic"},
            {name: "key-play-pause", globalName: "global-key-play-pause", title: "Play / pause", group: "Playback"}]
        values: ({"key-toggle-fullscreen": "f", "key-play-pause": "Space"})
        dirty: true
        onCancelRequested: close()
        onSaveRequested: close()
    }
    SignalSpy { id: captureSpy; target: shortcutEditor; signalName: "captureRequested" }
    SignalSpy { id: cancelSpy; target: shortcutEditor; signalName: "cancelRequested" }
    SignalSpy { id: saveSpy; target: shortcutEditor; signalName: "saveRequested" }
    function init() {
        shortcutEditor.close()
        startupVolume.visible = false; deviceRow.visible = false; volumeStepRow.visible = false; store.refreshCount = 0
        equalizer.visible = false; equalizer.expanded = false
        equalizerStore.gains = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]; equalizerStore.preamp = 12; equalizerStore.revision++
        captureSpy.clear(); cancelSpy.clear(); saveSpy.clear()
        store.values = {resize: true, fastSeek: false, timeout: 1800, clickPolicy: "auto", "volume-save": true, "redesign-startup-volume": 200, device: "", volumeStep: 12.800000190734863}
        store.revision++
        wait(20)
    }
    function test_volumeStepUsesPercentagePoints() {
        volumeStepRow.visible = true
        const field = findChild(volumeStepRow, "preferenceTextEditor")
        compare(field.text, "5.0")
        field.text = "2"; field.editingFinished()
        fuzzyCompare(store.value("volumeStep"), 5.12, 0.000001)
    }
    function test_startupVolumeOffersRememberAndFixedChoices() {
        startupVolume.visible = true
        const field = findChild(startupVolume, "startupVolumeField")
        verify(startupVolume.remember)
        verify(!field.enabled)
        mouseClick(findChild(startupVolume, "fixedStartupVolume"))
        compare(store.value("volume-save"), false)
        verify(field.enabled)
        field.text = "150"; field.editingFinished()
        compare(store.value("redesign-startup-volume"), 150)
        const remember = findChild(startupVolume, "rememberStartupVolume")
        remember.forceActiveFocus(); keyClick(Qt.Key_Space)
        compare(store.value("volume-save"), true)
        verify(!field.enabled)
        compare(store.value("redesign-startup-volume"), 150)
    }
    function test_startupVolumeShowsRejectedValue() {
        startupVolume.visible = true
        mouseClick(findChild(startupVolume, "fixedStartupVolume"))
        const field = findChild(startupVolume, "startupVolumeField")
        field.text = "301"; field.editingFinished()
        verify(field.invalid)
        compare(store.value("redesign-startup-volume"), 200)
        field.text = "125"; field.editingFinished()
        verify(!field.invalid)
        compare(store.value("redesign-startup-volume"), 125)
    }
    function test_deviceChoicesRefreshAndUseNativeIdentifiers() {
        deviceRow.visible = true
        const choice = findChild(deviceRow, "preferenceChoiceEditor")
        compare(choice.displayText, "System default")
        choice.forceActiveFocus(); choice.popup.open()
        compare(store.refreshCount, 1)
        keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
        compare(store.value("device"), "native-headphones")
        compare(choice.displayText, "Headphones")
    }
    function test_friendlyClickChoiceKeepsNativePolicyValue() {
        const choice = findChild(clickPolicyRow, "preferenceChoiceEditor")
        compare(choice.displayText, "Play / Pause")
        choice.forceActiveFocus(); keyClick(Qt.Key_Down)
        compare(store.value("clickPolicy"), "disabled")
        compare(choice.displayText, "Do nothing")
    }
    function test_dependentEditorStaysVisibleWhenDisabled() {
        const field = findChild(remotePortRow, "preferenceTextEditor")
        verify(field.enabled)
        store.stage("resize", false)
        verify(remotePortRow.visible)
        verify(!field.enabled)
        store.stage("resize", true)
        verify(field.enabled)
    }
    function test_equalizerExpandsAndEditsIndividualGains() {
        equalizer.visible = true
        mouseClick(findChild(equalizer, "equalizerExpander"))
        verify(equalizer.expanded)
        const preamp = findChild(equalizer, "equalizerValue_0")
        compare(preamp.text, "12.0")
        preamp.text = "3.5"; preamp.editingFinished()
        compare(equalizerStore.preamp, 3.5)
        const band = findChild(equalizer, "equalizerValue_1")
        band.text = "6.2"; band.editingFinished()
        compare(equalizerStore.gains[0], 6.2)
        compare(equalizerStore.gains[1], 1)
        band.text = "21"; band.editingFinished()
        verify(band.invalid)
        compare(equalizerStore.gains[0], 6.2)
        const slider = findChild(equalizer, "equalizerSlider_2")
        slider.forceActiveFocus(); keyClick(Qt.Key_Up)
        verify(equalizerStore.gains[1] > 1)
        mouseClick(findChild(equalizer, "equalizerExpander"))
        verify(!equalizer.expanded)
    }
    function test_guidedChoiceWritesUnderlyingBoolean() {
        const choice = findChild(resizeRow, "preferenceChoiceEditor")
        compare(choice.currentIndex, 1)
        choice.forceActiveFocus()
        keyClick(Qt.Key_Up)
        compare(store.value("resize"), false)
    }
    function test_preciseSeekingInvertsFastSeekOption() {
        const toggle = findChild(seekRow, "preferenceToggleEditor")
        verify(toggle.checked)
        mouseClick(toggle)
        compare(store.value("fastSeek"), true)
        verify(!toggle.checked)
    }
    function test_secondsSliderWritesMilliseconds() {
        const slider = findChild(delayRow, "preferenceSliderEditor")
        compare(slider.value, 1.8)
        mouseClick(slider, slider.width / 2, slider.height / 2)
        verify(store.value("timeout") >= 4900 && store.value("timeout") <= 5100)
    }
    function test_numericTextShowsUnitsAndPreservesNativeScale() {
        const field = findChild(timingTextRow, "preferenceTextEditor")
        compare(field.text, "1.8")
        verify(field.height >= 34)
        verify(timingTextRow.height >= 44)
        field.text = "2.4"
        field.editingFinished()
        compare(store.value("timeout"), 2400)
        field.text = "invalid"
        field.editingFinished()
        verify(field.invalid)
        compare(store.value("timeout"), 2400)
        field.text = ""
        field.editingFinished()
        verify(field.invalid)
        compare(store.value("timeout"), 2400)
    }
    function test_simpleAndAdvancedHaveDifferentContents() {
        const basicGeneral = catalog.sections.general.reduce((names, section) => names.concat(section.rows.map(row => row[0])), [])
        const advancedGeneral = catalog.advancedSections.general.reduce((names, section) => names.concat(section.rows.map(row => row[0])), [])
        verify(!basicGeneral.includes("stats"))
        verify(advancedGeneral.includes("stats"))
        const playback = catalog.sections.playback.reduce((names, section) => names.concat(section.rows.map(row => row[0])), [])
        verify(playback.includes("redesign-repeat"))
        verify(!playback.includes("repeat"))
        verify(!playback.includes("loop"))
        verify(!playback.includes("input-timeshift-path"))
        const audio = catalog.sections.audio.reduce((names, section) => names.concat(section.rows.map(row => row[0])), [])
        verify(audio.includes("redesign-audio-device"))
        verify(!audio.includes("aout"))
        verify(catalog.advancedSections.audio.some(section => section.rows.some(row => row[0] === "aout")))
        verify(catalog.advancedSections.playback[0].rows.some(row => row[0] === "input-timeshift-path"))
    }
    function test_shortcutEditorRecordsKeys() {
        shortcutEditor.open()
        tryCompare(shortcutEditor, "opened", true)
        tryVerify(() => !!findChild(shortcutEditor.contentItem, "shortcut_key-toggle-fullscreen"))
        const cell = findChild(shortcutEditor.contentItem, "shortcut_key-toggle-fullscreen")
        mouseClick(cell)
        compare(shortcutEditor.recordingName, "key-toggle-fullscreen")
        keyClick(Qt.Key_F2, Qt.ControlModifier)
        compare(captureSpy.count, 1)
        compare(captureSpy.signalArguments[0][0], "key-toggle-fullscreen")
        compare(captureSpy.signalArguments[0][1], Qt.Key_F2)
        compare(captureSpy.signalArguments[0][2], Qt.ControlModifier)
    }
    function test_shortcutEditorSearchAndCancel() {
        shortcutEditor.open()
        tryCompare(shortcutEditor, "opened", true)
        wait(20)
        const search = findChild(shortcutEditor.contentItem, "shortcutSearch")
        search.text = "pause"
        compare(findChild(shortcutEditor.contentItem, "shortcutList").count, 1)
        mouseClick(findChild(shortcutEditor.contentItem, "shortcutCancel"))
        compare(cancelSpy.count, 1)
        compare(saveSpy.count, 0)
        compare(shortcutEditor.values["key-play-pause"], "Space")
    }
    function test_shortcutEditorHasExplicitSave() {
        shortcutEditor.open()
        tryCompare(shortcutEditor, "opened", true)
        wait(20)
        mouseClick(findChild(shortcutEditor.contentItem, "shortcutSave"))
        compare(saveSpy.count, 1)
        compare(cancelSpy.count, 0)
    }

}
