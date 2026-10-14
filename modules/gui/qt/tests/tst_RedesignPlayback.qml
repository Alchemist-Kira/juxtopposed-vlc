// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedPlayback"
    width: 420; height: 600
    visible: true; when: windowShown
    property real rateValue: 1
    property bool canReverse: true
    property bool statisticsVisible: false
    property bool timelineVisible: false
    RedesignSleepTimer { id: sleepTimer }
    SignalSpy { id: expirySpy; target: sleepTimer; signalName: "triggered" }
    ListModel { id: visualizations }
    Loader {
        id: panelLoader
        x: 24; y: 24; width: 352
        sourceComponent: RedesignPlaybackSettings {
            playbackRate: testCase.rateValue; rateAvailable: true
            reversed: testCase.rateValue < 0; reverseAvailable: testCase.canReverse
            sleepTimerMinutes: sleepTimer.minutes
            visualizationModel: visualizations
            showStatistics: testCase.statisticsVisible
            showSubtitleTimeline: testCase.timelineVisible
            onSubtitleTimelineRequested: enabled => testCase.timelineVisible = enabled
            onRateRequested: value => testCase.rateValue = (testCase.rateValue < 0 ? -1 : 1) * value
            onReverseRequested: reversed => testCase.rateValue = (reversed ? -1 : 1) * Math.abs(testCase.rateValue)
            onSleepTimerRequested: minutes => sleepTimer.start(minutes)
            onStatisticsRequested: enabled => testCase.statisticsVisible = enabled
            onVisualizationRequested: index => {
                for (let i = 0; i < visualizations.count; ++i) visualizations.setProperty(i, "checked", i === index)
            }
        }
    }
    function init() {
        sleepTimer.start(0); expirySpy.clear()
        rateValue = 1; canReverse = true; statisticsVisible = false; timelineVisible = false
        visualizations.clear()
        visualizations.append({display: "Disable", checked: true})
        visualizations.append({display: "Spectrum", checked: false})
        visualizations.append({display: "Scope", checked: false})
        panelLoader.active = true
        tryVerify(() => panelLoader.item !== null)
        wait(20)
    }
    function field(name) { return findChild(panelLoader.item, name) }
    function test_subtitleTimelineIsFirstAndAcceptsMouseAndKeyboard() {
        const row = field("showSubtitleTimelineSetting")
        verify(row.y < field("showStatisticsSetting").y)
        const toggle = findChild(row, "settingSwitch")
        verify(!toggle.checked)
        mouseClick(toggle); verify(timelineVisible)
        toggle.forceActiveFocus(); keyClick(Qt.Key_Space)
        verify(!timelineVisible)
    }
    function editRate(text) {
        const input = field("settingValueField")
        mouseClick(input)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (const letter of text) keyClick(letter)
        keyClick(Qt.Key_Return)
    }
    function test_nativeModelDropdownTracksSelectionAndReset() {
        const choice = field("modelChoiceField")
        compare(choice.currentIndex, 0)
        compare(choice.displayText, "Disabled")
        mouseClick(choice)
        keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
        compare(choice.currentIndex, 1)
        compare(choice.displayText, "Spectrum")
        visualizations.setProperty(1, "checked", false)
        visualizations.setProperty(2, "checked", true)
        compare(choice.currentIndex, 2)
        compare(choice.displayText, "Scope")
        visualizations.clear()
        compare(choice.currentIndex, -1)
        verify(!choice.enabled)
        visualizations.append({display: "Disable", checked: true})
        tryCompare(choice, "currentIndex", 0)
        verify(choice.enabled)
        compare(choice.displayText, "Disabled")
    }
    function test_reverseAndSpeedKeepTheSameMagnitude() {
        rateValue = 1.5
        const toggle = findChild(field("reverseSetting"), "settingSwitch")
        mouseClick(toggle)
        compare(rateValue, -1.5)
        compare(field("settingValueField").displayText, "1.5x")
        editRate("1.25")
        compare(rateValue, -1.25)
        mouseClick(toggle)
        compare(rateValue, 1.25)
    }
    function test_reverseCapabilityDoesNotPreventReturningToForward() {
        canReverse = false
        const toggle = findChild(field("reverseSetting"), "settingSwitch")
        verify(!toggle.enabled)
        rateValue = -1.5
        verify(toggle.enabled)
        mouseClick(toggle)
        compare(rateValue, 1.5)
        verify(!toggle.enabled)
    }
    function test_speedFieldShowsRatesBeyondTheSliderScale() {
        rateValue = 4
        compare(field("settingValueField").displayText, "4x")
        compare(field("settingSlider").value, 2)
        editRate("3.25")
        compare(rateValue, 3.25)
        compare(field("settingValueField").displayText, "3.25x")
        rateValue = 1.25
        compare(field("settingValueField").contentItem.text, "1.25x")
        compare(field("settingTick_0").text, "0.25")
        compare(field("settingTick_3").text, "1")
        compare(field("settingTick_7").text, "2")
    }
    function test_speedFieldShowsTheNativeMinimumWithoutRoundingIt() {
        rateValue = 0.03125
        compare(field("settingValueField").displayText, "0.03125x")
        editRate("0.03125")
        compare(rateValue, 0.03125)
    }
    function test_sleepChoiceSurvivesPanelDestruction() {
        const choice = field("sleepTimerChoice")
        mouseClick(choice)
        keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
        compare(sleepTimer.minutes, 30)
        compare(choice.currentValue, 30)
        panelLoader.active = false
        compare(sleepTimer.minutes, 30)
        panelLoader.active = true
        tryVerify(() => panelLoader.item !== null)
        compare(field("sleepTimerChoice").currentValue, 30)
    }
    function test_sleepExpiryReturnsTheControlToOff() {
        sleepTimer.start(15)
        sleepTimer.clock.interval = 20
        tryCompare(expirySpy, "count", 1)
        compare(sleepTimer.minutes, 0)
        compare(field("sleepTimerChoice").currentValue, 0)
    }
    function test_cancelledSleepTimerDoesNotExpire() {
        sleepTimer.start(15)
        sleepTimer.clock.interval = 50
        sleepTimer.start(0)
        wait(80)
        compare(expirySpy.count, 0)
        compare(sleepTimer.minutes, 0)
    }
}
