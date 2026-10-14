// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedSubtitleTimeline"
    width: 800; height: 240
    visible: true; when: windowShown
    RedesignSeekBar {
        id: seek
        x: 20; y: 100; width: 760
        enabled: true
        timeForPosition: position => position.toFixed(3)
        onSubtitleDelayRequested: milliseconds => subtitleDelayMS = milliseconds
    }
    SignalSpy { id: seekSpy; target: seek; signalName: "moved" }
    SignalSpy { id: delaySpy; target: seek; signalName: "subtitleDelayRequested" }
    SignalSpy { id: previewSpy; target: seek; signalName: "previewRequested" }
    function init() {
        seek.scaleFactor = 1; seek.lightTheme = false
        seek.timelineEnabled = false
        seek.timelineState = "ready"; seek.durationSeconds = 100
        seek.timelineCues = [{start: 10, stop: 15}, {start: 12, stop: 20}, {start: 40, stop: 50}, {start: 80, stop: 85}]
        seek.subtitleDelayMS = 0; seek.previewEnabled = false
        seek.playbackPosition = Qt.binding(() => seek.value)
        seek.value = 0.25
        seekSpy.clear(); delaySpy.clear(); previewSpy.clear()
        mouseMove(testCase, 0, 0)
    }
    function dragArea() { return findChild(seek, "subtitleCueDragArea") }
    function xAt(position) { return (position - seek.from) / (seek.to - seek.from) * dragArea().width }
    function button(name) { return findChild(seek, name) }
    function test_offByDefaultAndNoInventedCues() {
        verify(!seek.timelineActive)
        seek.timelineEnabled = true
        verify(seek.timelineActive)
        seek.timelineState = "loading"; verify(!seek.timelineActive)
        seek.timelineState = "unavailable"; verify(!seek.timelineActive)
        seek.timelineState = "no-track"; verify(!seek.timelineActive)
        seek.timelineState = "ready"; seek.timelineCues = []
        verify(!seek.timelineActive)
        verify(!button("subtitleEarlierButton").visible)
        compare(seek.from, 0); compare(seek.to, 1)
    }
    function test_overlapsAndDenseIntervalsStayBoundedByScreenWidth() {
        seek.timelineEnabled = true
        compare(seek.mergedCues.length, 3)
        const cues = []
        for (let i = 0; i < 10000; ++i) cues.push({start: i / 100, stop: i / 100 + 0.002})
        seek.timelineCues = cues
        verify(seek.projectedCues.length <= dragArea().width)
        verify(seek.projectedCues.length > 0)
    }
    function test_timingArrowsUseSavedDelayAndKeyboard() {
        seek.timelineEnabled = true
        mouseClick(button("subtitleEarlierButton"))
        compare(seek.subtitleDelayMS, -100)
        const later = button("subtitleLaterButton")
        later.forceActiveFocus(); keyClick(Qt.Key_Space)
        compare(seek.subtitleDelayMS, 0)
        compare(delaySpy.count, 2); compare(seekSpy.count, 0)
    }
    function test_dragMovesCuesWithoutSeekingAndClampsNoVideo() {
        seek.timelineEnabled = true
        const area = dragArea(), initial = seek.value
        const start = xAt(0.45), move = area.width * 0.05
        mousePress(area, start, area.height / 2)
        mouseMove(area, start + move, area.height / 2, 30)
        verify(seek.cueDragging)
        verify(Math.abs(seek.displayedDelayMS - 5000) < 200)
        compare(seek.subtitleDelayMS, 0)
        compare(seek.value, initial)
        mouseRelease(area, start + move, area.height / 2)
        verify(Math.abs(seek.subtitleDelayMS - 5000) < 200)
        compare(delaySpy.count, 1); compare(seekSpy.count, 0)
    }
    function test_clickOnCueSeeksAndBlankPartRetainsNormalSeek() {
        seek.timelineEnabled = true
        const area = dragArea()
        mouseClick(area, xAt(0.45), area.height / 2)
        verify(Math.abs(seek.value - 0.45) < 0.01)
        compare(seekSpy.count, 1); compare(delaySpy.count, 0)
        mouseClick(area, xAt(0.65), area.height / 2)
        verify(Math.abs(seek.value - 0.65) < 0.01)
        verify(seekSpy.count >= 2)
    }
    function test_trackChangeDuringDragDoesNotEditTheNewTrack() {
        seek.timelineEnabled = true
        const area = dragArea(), start = xAt(0.45)
        mousePress(area, start, area.height / 2)
        mouseMove(area, start + 30, area.height / 2, 30)
        verify(seek.cueDragging)
        seek.timelineCues = [{start: 3, stop: 6}]
        verify(!seek.cueDragging)
        mouseRelease(area, start + 30, area.height / 2)
        compare(seek.subtitleDelayMS, 0)
        compare(delaySpy.count, 0); compare(seekSpy.count, 0)
    }
    function test_zoomKeepsGlobalSeekAndPreviewPositions() {
        seek.timelineEnabled = true
        seek.value = 0.45
        mouseClick(button("subtitleZoomInButton"))
        compare(seek.timelineZoom, 2)
        verify(Math.abs(seek.from - 0.2) < 0.001)
        verify(Math.abs(seek.to - 0.7) < 0.001)
        seek.previewEnabled = true
        const area = dragArea()
        mouseMove(area, xAt(0.6), area.height / 2)
        tryVerify(() => previewSpy.count > 0)
        verify(Math.abs(seek.previewPosition - 0.6) < 0.01)
        mouseClick(area, xAt(0.6), area.height / 2)
        verify(Math.abs(seek.value - 0.6) < 0.01)
        mouseClick(button("subtitleZoomOutButton"))
        compare(seek.from, 0); compare(seek.to, 1)
        verify(Math.abs(seek.value - 0.6) < 0.01)
    }
    function test_zoomFollowsPlaybackAndResetsForNewTrack() {
        seek.timelineEnabled = true; seek.value = 0.45
        seek.zoomTimeline(4)
        seek.playbackPosition = 0.9
        seek.value = 0.9
        verify(seek.from <= 0.9 && seek.to >= 0.9)
        seek.timelineCues = [{start: 1, stop: 2}]
        compare(seek.timelineZoom, 1)
        compare(seek.from, 0); compare(seek.to, 1)
    }
    function test_delayChangesAndLightScaledThemeUseRealIntervals() {
        seek.timelineEnabled = true
        const before = seek.projectedCues[0].start
        seek.subtitleDelayMS = 1000
        verify(seek.projectedCues[0].start > before)
        seek.lightTheme = true; seek.scaleFactor = 1.5
        compare(seek.height, 42)
        verify(seek.projectedCues[0].start >= 0)
        seek.subtitleDelayMS = -90000
        compare(seek.projectedCues.length, 0)
    }
}
