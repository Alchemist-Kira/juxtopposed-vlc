// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedPlayer"
    width: 1280
    height: 720
    when: windowShown
    visible: true

    RedesignPlayerView {
        id: player
        anchors.fill: parent
        started: true
        hasVideo: true
        seekable: true
        hasPrevious: true
        hasNext: true
        position: 0.25
        volume: 0.5
        timeText: "00:02:10"
        lengthText: "00:25:40"
        onTogglePlayback: playing = !playing
        onSeekRequested: value => position = value
        onVolumeRequested: value => volume = value
        onMuteRequested: muted = !muted
        libraryContent: RedesignLibraryView {
            scaleFactor: player.scaleFactor; lightTheme: player.lightTheme
            itemCount: 2
            mediaModel: ListModel {
                ListElement { title: "First video"; thumbnail: "" }
                ListElement { title: "Second video"; thumbnail: "" }
            }
        }
        queueContent: RedesignQueue {
            itemCount: 2
            queueModel: ListModel {
                ListElement { title: "First video"; isCurrent: true }
                ListElement { title: "Second video"; isCurrent: false }
            }
        }
    }
    SignalSpy { id: seekSpy; target: player; signalName: "seekRequested" }
    SignalSpy { id: audioSpy; target: player; signalName: "audioTracksRequested" }
    SignalSpy { id: subtitleSpy; target: player; signalName: "subtitleTracksRequested" }

    function init() {
        player.libraryOpen = false
        player.libraryExpanded = false
        player.queueOpen = false
        player.settingsPage = ""
        player.playing = false
        player.muted = false
        player.fullscreen = false
        player.lightTheme = false
        player.scaleFactor = 1
        testCase.width = 1280
        testCase.height = 720
        seekSpy.clear()
        audioSpy.clear()
        subtitleSpy.clear()
        wait(20)
    }
    function test_transportAndTrackActions() {
        mouseClick(findChild(player, "playButton"))
        verify(player.playing)
        mouseClick(findChild(player, "playButton"))
        verify(!player.playing)
        mouseClick(findChild(player, "muteButton"))
        verify(player.muted)
        mouseClick(findChild(player, "audioButton"))
        compare(audioSpy.count, 1)
        mouseClick(findChild(player, "subtitleButton"))
        compare(subtitleSpy.count, 1)
    }
    function test_seekUsesPointerAndKeyboard() {
        const slider = findChild(player, "seekBar")
        mouseClick(slider, slider.width * 0.75, slider.height / 2)
        verify(seekSpy.count > 0)
        verify(player.position > 0.7 && player.position < 0.8)
        slider.forceActiveFocus()
        const before = player.position
        keyClick(Qt.Key_Right)
        verify(player.position > before)
    }
    function test_panelsResizeVideo() {
        const viewport = findChild(player, "redesignViewport")
        const initialWidth = viewport.width
        mouseClick(findChild(player, "libraryToggleButton"))
        verify(player.libraryOpen)
        verify(viewport.width < initialWidth)
        verify(viewport.x >= findChild(player, "redesignLibraryPanel").width)
        mouseClick(findChild(player, "queueButton"))
        verify(player.queueOpen)
        verify(viewport.width > 0)
        mouseClick(findChild(player, "playbackSettingsButton"))
        compare(player.settingsPage, "playback")
        verify(!player.queueOpen)
        player.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        verify(!player.libraryOpen)
        compare(player.settingsPage, "")
    }
    function test_minimumWindowAndScaling() {
        testCase.width = 640
        testCase.height = 360
        wait(20)
        const seek = findChild(player, "seekBar")
        verify(seek.width >= 40)
        const queue = findChild(player, "queueButton")
        verify(queue.x + queue.width <= queue.parent.width)
        testCase.width = 1920
        testCase.height = 1080
        player.scaleFactor = 1.5
        wait(20)
        compare(findChild(player, "redesignToolbar").height, 81)
        verify(findChild(player, "redesignViewport").height > 0)
    }
    function test_lightPaletteAndExpandedLibrary() {
        player.lightTheme = true
        compare(player.theme.background.toString(), "#acacac")
        compare(player.theme.panel.toString(), "#c3c3c3")
        player.libraryOpen = true
        player.libraryExpanded = true
        wait(20)
        const viewport = findChild(player, "redesignViewport")
        verify(viewport.width > 0 && viewport.width <= 320)
        verify(viewport.height === 180)
        player.libraryOpen = false
        verify(!player.libraryExpanded)
    }
    function test_fullscreenUsesIndependentEdges() {
        player.fullscreen = true
        player.forceActiveFocus()
        mouseMove(player, player.width / 2, player.height / 2)
        wait(1900)
        verify(!player.topVisible)
        verify(!player.bottomVisible)
        mouseMove(player, player.width / 2, 2)
        tryCompare(player, "topVisible", true)
        verify(!player.bottomVisible)
        mouseMove(player, player.width / 2, player.height - 2)
        tryCompare(player, "bottomVisible", true)
    }
}
