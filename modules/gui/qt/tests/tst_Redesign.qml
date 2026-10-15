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
    property var seekEventOrder: []
    property bool consumeVideoHover: false

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
        timeForPosition: position => Number(position).toFixed(3)
        onTogglePlayback: playing = !playing
        onSeekRequested: value => { testCase.seekEventOrder.push("seek"); position = value }
        onSeekDragStarted: testCase.seekEventOrder.push("start")
        onSeekDragFinished: testCase.seekEventOrder.push("finish")
        onVolumeRequested: value => volume = value
        onMuteRequested: muted = !muted
        // VideoSurface accepts hover events in the integrated player.
        videoContent: MouseArea {
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: testCase.consumeVideoHover
        }
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
    ListModel {
        id: tracks
        ListElement { display: "English"; checked: true }
        ListElement { display: "Japanese"; checked: false }
    }
    RedesignTrackPopup {
        id: trackPicker
        parent: testCase
        x: 20; y: 20
        videoTracks: tracks; audioTracks: tracks; subtitleTracks: tracks
        audioDevices: tracks
        onSelectionRequested: (model, index, selected) => {
            for (let i = 0; i < model.count; ++i) model.setProperty(i, "checked", i === index && selected)
        }
        onDisableRequested: model => {
            for (let i = 0; i < model.count; ++i) model.setProperty(i, "checked", false)
        }
    }
    SignalSpy { id: trackSelectionSpy; target: trackPicker; signalName: "selectionRequested" }
    SignalSpy { id: trackPreferencesSpy; target: trackPicker; signalName: "preferencesRequested" }
    SignalSpy { id: seekSpy; target: player; signalName: "seekRequested" }
    SignalSpy { id: seekDragStartSpy; target: player; signalName: "seekDragStarted" }
    SignalSpy { id: seekDragFinishSpy; target: player; signalName: "seekDragFinished" }
    SignalSpy { id: previewSpy; target: player; signalName: "seekPreviewRequested" }
    SignalSpy { id: previewEndSpy; target: player; signalName: "seekPreviewEnded" }
    SignalSpy { id: audioSpy; target: player; signalName: "audioTracksRequested" }
    SignalSpy { id: subtitleSpy; target: player; signalName: "subtitleTracksRequested" }
    SignalSpy { id: toolbarVisibilitySpy; target: player; signalName: "bottomVisibleChanged" }

    RedesignSettingSlider {
        id: settingControl
        x: 20; y: 20; width: 360; z: 10
        visible: false
        label: "Subtitle Speed"; suffix: " fps"; decimals: 3
        from: 0; to: 60; stepSize: 0.001
        resetValue: 0; minimumValueText: "Automatic"
        onMoved: value => currentValue = value
    }
    SignalSpy { id: settingSpy; target: settingControl; signalName: "moved" }
    RedesignSwitchRow {
        id: statisticsSwitch
        x: 20; y: 20; width: 360; z: 10
        visible: false
        label: "Show Statistics"; checked: player.showStatistics
        onToggled: checked => player.showStatistics = checked
    }

    function init() {
        consumeVideoHover = false
        settingControl.visible = false
        settingControl.currentValue = 0
        settingControl.resetValue = 0
        settingSpy.clear()
        statisticsSwitch.visible = false
        player.showStatistics = false
        player.showSubtitleTimeline = false
        player.showSeekPreview = true
        player.subtitleTimelineCues = []
        player.subtitleTimelineState = "off"
        player.statistics = ({})
        player.started = true
        trackPicker.close()
        trackPicker.page = "subtitles"
        tracks.setProperty(0, "checked", true)
        tracks.setProperty(1, "checked", false)
        trackSelectionSpy.clear()
        trackPreferencesSpy.clear()
        player.libraryOpen = false
        player.libraryExpanded = false
        player.queueOpen = false
        player.settingsPage = ""
        player.playing = false
        player.muted = false
        player.fullscreen = false
        player.minimalView = false
        player.started = true
        player.hasVideo = true
        player.autoHideMode = 1
        player.lightTheme = false
        player.scaleFactor = 1
        player.seekPreviewImage = ""
        player.seekPreviewImagePosition = -1
        player.forceActiveFocus()
        mouseMove(player, 20, 200)
        testCase.width = 1280
        testCase.height = 720
        seekSpy.clear()
        seekEventOrder = []
        seekDragStartSpy.clear()
        seekDragFinishSpy.clear()
        previewSpy.clear()
        previewEndSpy.clear()
        audioSpy.clear()
        subtitleSpy.clear()
        tryCompare(findChild(player, "redesignLibraryPanel"), "reveal", 0)
        wait(20)
    }
    function test_statisticsSwitchUsesMouseAndKeyboard() {
        statisticsSwitch.visible = true
        const toggle = findChild(statisticsSwitch, "settingSwitch")
        mouseClick(toggle)
        verify(player.showStatistics)
        toggle.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(!player.showStatistics)
        player.showStatistics = true
        verify(toggle.checked)
    }
    function test_zoomedSubtitleTimelineFollowsGlobalPlayerPosition() {
        player.showSubtitleTimeline = true
        player.subtitleTimelineState = "ready"
        player.subtitleTimelineCues = [{start: 10, stop: 20}, {start: 80, stop: 95}]
        player.durationSeconds = 100
        player.position = 0.45
        const seek = findChild(player, "seekBar")
        seek.zoomTimeline(4)
        player.position = 0.9
        tryVerify(() => seek.from <= 0.9 && seek.to >= 0.9)
        tryCompare(seek, "value", 0.9)
        const viewport = findChild(player, "redesignViewport")
        const before = [viewport.x, viewport.y, viewport.width, viewport.height]
        player.libraryOpen = true; player.settingsPage = "playback"
        wait(220)
        compare([viewport.x, viewport.y, viewport.width, viewport.height], before)
    }
    function test_dragPastSeekbarEndClampsAndCancelsWhenMediaStops() {
        const seek = findChild(player, "seekBar")
        player.position = 0.95
        mousePress(seek, seek.width - 20, seek.height / 2)
        mouseMove(seek, seek.width + 200, seek.height / 2, 40)
        compare(player.position, 1)
        verify(seekSpy.count > 0)
        player.started = false
        player.seekable = false
        tryCompare(seek, "pressed", false)
        verify(!seek.previewActive)
        compare(seekDragStartSpy.count, 1)
        tryCompare(seekDragFinishSpy, "count", 1)
        compare(seekDragFinishSpy.signalArguments[0][1], false)
        mouseRelease(seek, seek.width + 200, seek.height / 2)
        player.seekable = true
    }
    function test_dragPastSeekbarEndCommitsOnlyOnRelease() {
        const seek = findChild(player, "seekBar")
        player.position = 0.25
        mousePress(seek, seek.width / 2, seek.height / 2)
        compare(seekDragStartSpy.count, 1)
        compare(seekEventOrder[0], "start")
        mouseMove(seek, seek.width + 200, seek.height / 2, 40)
        compare(player.position, 1)
        compare(seekDragFinishSpy.count, 0)
        wait(100)
        verify(seek.pressed)
        mouseRelease(seek, seek.width + 200, seek.height / 2)
        tryCompare(seekDragFinishSpy, "count", 1)
        compare(seekDragFinishSpy.signalArguments[0][0], 1)
        compare(seekDragFinishSpy.signalArguments[0][1], true)
    }
    function test_pressAtSeekbarEndStartsHoldBeforeSeeking() {
        const seek = findChild(player, "seekBar")
        player.position = 0.25
        mousePress(seek, seek.width - 2, seek.height / 2)
        compare(seekEventOrder[0], "start")
        compare(seekDragStartSpy.count, 1)
        compare(seekDragFinishSpy.count, 0)
        mouseRelease(seek, seek.width - 2, seek.height / 2)
        tryCompare(seekDragFinishSpy, "count", 1)
        compare(seekDragFinishSpy.signalArguments[0][0], 1)
        compare(seekDragFinishSpy.signalArguments[0][1], true)
    }
    function test_keyboardSeekDoesNotStartPointerDrag() {
        const seek = findChild(player, "seekBar")
        player.position = 0.4
        seek.forceActiveFocus()
        keyClick(Qt.Key_Right)
        verify(seekSpy.count > 0)
        compare(seekDragStartSpy.count, 0)
        compare(seekDragFinishSpy.count, 0)
    }
    function test_subtitleTimelineControlsDoNotStartSeekDrag() {
        player.showSubtitleTimeline = true
        player.subtitleTimelineState = "ready"
        player.subtitleTimelineCues = [{start: 10, stop: 30}]
        player.durationSeconds = 100
        mouseClick(findChild(player, "subtitleEarlierButton"))
        mouseClick(findChild(player, "subtitleZoomInButton"))
        compare(seekDragStartSpy.count, 0)
        compare(seekDragFinishSpy.count, 0)
        compare(seekSpy.count, 0)
    }
    function test_statisticsOverlayUpdatesAndFitsVideo() {
        const overlay = findChild(player, "playbackStatisticsOverlay")
        verify(!overlay.visible)
        player.statistics = ({decodedVideo: 123, inputBitrate: 456})
        player.showStatistics = true
        verify(overlay.visible)
        compare(findChild(overlay, "statistic_decodedVideo").text, "123")
        compare(findChild(overlay, "statistic_inputBitrate").text, "456 kb/s")
        player.statistics = ({decodedVideo: 321, inputBitrate: 654})
        compare(findChild(overlay, "statistic_decodedVideo").text, "321")
        testCase.width = 640; testCase.height = 360
        player.libraryOpen = true; player.settingsPage = "playback"
        wait(20)
        const viewport = findChild(player, "redesignViewport")
        verify(overlay.width <= Math.max(0, viewport.width - 24))
        verify(overlay.height <= Math.max(0, viewport.height - 24))
        player.started = false
        verify(!overlay.visible)
    }
    function test_subtitleFrameRateAcceptsDecimalsAndAutomatic_data() {
        return [{tag: "decimal-point", locale: "en_US", decimal: Qt.Key_Period, expected: "23.976 fps"},
                {tag: "decimal-comma", locale: "de_DE", decimal: Qt.Key_Comma, expected: "23,976 fps"}]
    }
    function test_subtitleFrameRateAcceptsDecimalsAndAutomatic(data) {
        settingControl.visible = true
        const field = findChild(settingControl, "settingValueField")
        field.locale = Qt.locale(data.locale)
        compare(field.displayText, "Automatic")
        mouseClick(field)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        keyClick(Qt.Key_2); keyClick(Qt.Key_3); keyClick(data.decimal)
        keyClick(Qt.Key_9); keyClick(Qt.Key_7); keyClick(Qt.Key_6)
        keyClick(Qt.Key_Return)
        compare(settingSpy.count, 1)
        compare(settingControl.currentValue, 23.976)
        compare(field.displayText, data.expected)
        compare(field.contentItem.text, data.expected)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (const letter of "Automatic") keyClick(letter)
        keyClick(Qt.Key_Return)
        compare(settingControl.currentValue, 0)
        compare(field.displayText, "Automatic")
        compare(field.contentItem.text, "Automatic")
    }
    function test_settingResetUsesItsOwnDefault_data() {
        return [{tag: "subtitle-fps", value: 23.976, reset: 0},
                {tag: "playback-speed", value: 2, reset: 1},
                {tag: "track-delay", value: 4, reset: 0}]
    }
    function test_settingResetUsesItsOwnDefault(data) {
        settingControl.visible = true
        settingControl.currentValue = data.value
        settingControl.resetValue = data.reset
        mouseClick(findChild(settingControl, "settingResetButton"))
        compare(settingSpy.count, 1)
        compare(settingControl.currentValue, data.reset)
    }
    function test_subtitleFrameRateRejectsInvalidAndOutOfRangeInput_data() {
        return [{tag: "text", keys: [Qt.Key_X]},
                {tag: "empty", keys: [Qt.Key_Backspace]},
                {tag: "above-range", keys: [Qt.Key_6, Qt.Key_1]},
                {tag: "below-range", keys: [Qt.Key_Minus, Qt.Key_1]}]
    }
    function test_subtitleFrameRateRejectsInvalidAndOutOfRangeInput(data) {
        settingControl.visible = true
        settingControl.currentValue = 25
        const field = findChild(settingControl, "settingValueField")
        field.locale = Qt.locale("en_US")
        mouseClick(field)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (const key of data.keys) keyClick(key)
        keyClick(Qt.Key_Return)
        compare(settingControl.currentValue, 25)
        compare(field.displayText, "25.000 fps")
        compare(field.contentItem.text, "25.000 fps")
        compare(settingSpy.count, 0)
    }
    function test_trackPickerSelectsAndDisablesTracks() {
        trackPicker.open()
        wait(30)
        const choices = findChild(trackPicker, "embeddedTrackChoices")
        verify(choices.hasSelection)
        const japanese = findChild(choices, "trackChoice_1")
        mouseClick(japanese)
        compare(trackSelectionSpy.count, 1)
        verify(tracks.get(1).checked)
        verify(!tracks.get(0).checked)
        // Selecting the current radio choice keeps it selected.
        mouseClick(japanese)
        verify(tracks.get(1).checked)
        const none = findChild(choices, "disableTracks")
        none.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(!choices.hasSelection)
        verify(none.chosen)
        // The same None action is available on video and audio pages.
        mouseClick(findChild(trackPicker.contentItem, "trackTab_audio"))
        compare(trackPicker.page, "audio")
        verify(none.visible)
        mouseClick(findChild(trackPicker.contentItem, "trackTab_video"))
        compare(trackPicker.page, "video")
        verify(none.visible)
        mouseClick(findChild(trackPicker.contentItem, "trackPreferencesButton"))
        compare(trackPreferencesSpy.count, 1)
        compare(trackPreferencesSpy.signalArguments[0][0], "video")
        verify(!trackPicker.opened)
    }
    function test_trackPickerFitsSmallWindow() {
        testCase.width = 640; testCase.height = 360
        trackPicker.open()
        wait(30)
        verify(trackPicker.height <= testCase.height - 114)
        verify(findChild(trackPicker.contentItem, "trackTab_subtitles").visible)
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
    readonly property url previewFixture: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAIAAAC0SDtlAAAAFUlEQVR4nGP8z0AaYCJR/agG2mgAAMeRARHH28OHAAAAAElFTkSuQmCC"
    function test_seekPreviewCanBeTurnedOffAndOn() {
        const slider = findChild(player, "seekBar")
        const popup = findChild(slider, "seekThumbnailPopup")
        verify(player.showSeekPreview)
        mouseMove(slider, slider.width / 2, slider.height / 2)
        tryVerify(() => previewSpy.count > 0)
        player.seekPreviewImagePosition = slider.previewPosition
        player.seekPreviewImage = previewFixture
        tryCompare(popup, "visible", true)
        player.showSeekPreview = false
        tryCompare(popup, "visible", false)
        const count = previewSpy.count
        mouseMove(slider, slider.width * .7, slider.height / 2)
        wait(200)
        compare(previewSpy.count, count)
        verify(previewEndSpy.count > 0)
        player.showSeekPreview = true
        tryVerify(() => previewSpy.count > count)
        tryCompare(popup, "visible", true)
    }
    function test_seekHoverPreviewDoesNotSeekOrMoveTheVideo() {
        const slider = findChild(player, "seekBar")
        const popup = findChild(slider, "seekThumbnailPopup")
        const bounds = videoBounds()
        const before = player.position
        mouseMove(slider, slider.width / 2, slider.height / 2)
        tryVerify(() => previewSpy.count > 0)
        compare(seekSpy.count, 0); compare(player.position, before)
        player.seekPreviewImagePosition = slider.previewPosition
        player.seekPreviewImage = previewFixture
        tryCompare(popup, "visible", true)
        compare(popup.width, 272); compare(popup.height, 189)
        compare(videoBounds(), bounds)
        mouseMove(player, 20, 200)
        tryCompare(popup, "visible", false)
        verify(previewEndSpy.count > 0)
    }
    function test_seekPreviewKeepsItsOwnTimestampWhileLoadingAndStopsForAudio() {
        const slider = findChild(player, "seekBar")
        const popup = findChild(slider, "seekThumbnailPopup")
        mouseMove(slider, slider.width * .25, slider.height / 2)
        tryVerify(() => previewSpy.count > 0)
        player.seekPreviewImagePosition = slider.previewPosition
        player.seekPreviewImage = previewFixture
        tryCompare(popup, "visible", true)
        const time = findChild(popup.contentItem, "seekThumbnailTime")
        const previousTime = time.text
        mouseMove(slider, slider.width * .75, slider.height / 2)
        verify(popup.visible)
        compare(time.text, previousTime)
        player.seekPreviewImagePosition = slider.previewPosition
        verify(popup.visible)
        verify(time.text !== previousTime)
        const before = previewSpy.count
        player.refreshSeekPreview()
        tryVerify(() => previewSpy.count > before)
        player.hasVideo = false
        tryCompare(popup, "visible", false)
        const count = previewSpy.count
        mouseMove(slider, slider.width / 2, slider.height / 2)
        wait(200)
        compare(previewSpy.count, count)
    }
    function test_seekPreviewFitsWindowEdgesAndWorksDuringScrubbing() {
        testCase.width = 640
        const slider = findChild(player, "seekBar")
        const popup = findChild(slider, "seekThumbnailPopup")
        wait(30)
        mousePress(slider, slider.width - 2, slider.height / 2)
        tryVerify(() => previewSpy.count > 0)
        player.seekPreviewImagePosition = slider.previewPosition
        player.seekPreviewImage = previewFixture
        tryCompare(popup, "visible", true)
        const point = popup.contentItem.parent.mapToItem(testCase, 0, 0)
        verify(point.x >= 0); verify(point.x + popup.width <= testCase.width)
        mouseMove(slider, 2, slider.height / 2)
        tryVerify(() => previewSpy.count > 1)
        player.seekPreviewImagePosition = slider.previewPosition
        tryCompare(popup, "visible", true)
        verify(popup.contentItem.parent.mapToItem(testCase, 0, 0).x >= 0)
        mouseRelease(slider, 2, slider.height / 2)
    }
    function videoBounds() {
        const viewport = findChild(player, "redesignViewport")
        return Qt.rect(viewport.x, viewport.y, viewport.width, viewport.height)
    }
    function test_panelsOverlayVideo() {
        const viewport = findChild(player, "redesignViewport")
        const bounds = videoBounds()
        const sidebar = findChild(player, "redesignLibraryPanel")
        mouseClick(findChild(player, "libraryToggleButton"))
        verify(player.libraryOpen)
        tryCompare(sidebar, "reveal", 1)
        compare(videoBounds(), bounds)
        verify(sidebar.x < viewport.x + viewport.width && sidebar.x + sidebar.width > viewport.x)
        mouseClick(findChild(player, "queueButton"))
        verify(player.queueOpen)
        compare(videoBounds(), bounds)
        mouseClick(findChild(player, "playbackSettingsButton"))
        compare(player.settingsPage, "playback")
        verify(!player.queueOpen)
        compare(videoBounds(), bounds)
        player.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        verify(!player.libraryOpen)
        compare(player.settingsPage, "")
        tryCompare(sidebar, "reveal", 0)
        compare(videoBounds(), bounds)
        trackPicker.open()
        wait(30)
        compare(videoBounds(), bounds)
    }
    function test_sidebarSlideAndIconStaySynchronized() {
        const sidebar = findChild(player, "redesignLibraryPanel")
        const button = findChild(player, "libraryToggleButton")
        const bounds = videoBounds()
        player.libraryOpen = true
        wait(32)
        verify(sidebar.reveal > 0 && sidebar.reveal < 1)
        verify(sidebar.x < 0 && sidebar.x > -sidebar.width)
        compare(button.iconReveal, sidebar.reveal)
        compare(videoBounds(), bounds)
        // A second click reverses an unfinished slide without a jump in video size.
        player.libraryOpen = false
        verify(sidebar.visible)
        tryCompare(sidebar, "reveal", 0)
        verify(!sidebar.visible)
        compare(button.iconReveal, 0)
        compare(videoBounds(), bounds)
        player.libraryOpen = true
        tryCompare(sidebar, "reveal", 1)
        compare(sidebar.x, 0)
        compare(button.iconReveal, 1)
    }
    function test_sidebarKeepsItsPageWhenClosed() {
        const sidebar = findChild(player, "redesignLibraryPanel")
        player.libraryOpen = true
        tryCompare(sidebar, "reveal", 1)
        const content = player.libraryItem
        content.category = 4
        player.libraryOpen = false
        tryCompare(sidebar, "reveal", 0)
        compare(player.libraryItem, content)
        player.libraryOpen = true
        tryCompare(sidebar, "reveal", 1)
        compare(player.libraryItem.category, 4)
    }
    function test_overlaysKeepVideoBoundsInFullscreenAndSmallWindow_data() {
        return [{tag: "fullscreen", fullscreen: true, width: 1280, height: 720},
                {tag: "small-window", fullscreen: false, width: 640, height: 360}]
    }
    function test_overlaysKeepVideoBoundsInFullscreenAndSmallWindow(data) {
        player.fullscreen = data.fullscreen
        testCase.width = data.width; testCase.height = data.height
        wait(20)
        const bounds = videoBounds()
        player.libraryOpen = true
        player.settingsPage = "audio"
        wait(170)
        compare(videoBounds(), bounds)
        player.settingsPage = "subtitles"
        compare(videoBounds(), bounds)
        player.settingsPage = ""
        player.queueOpen = true
        compare(videoBounds(), bounds)
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
    function test_audioAfterVideoRestoresHiddenControls() {
        player.fullscreen = true
        player.autoHideMode = 2
        player.forceActiveFocus()
        mouseMove(player, player.width / 2, player.height / 2)
        wait(1900)
        verify(!player.bottomVisible)
        player.hasVideo = false
        tryCompare(player, "bottomVisible", true)
        player.hasVideo = true
        player.revealControls()
        verify(player.bottomVisible)
        player.started = false
        verify(player.bottomVisible)
    }
    function test_minimalViewHidesChromeAndClosesPanels() {
        player.resumeAvailable = true
        player.showStatistics = true
        player.libraryOpen = true
        player.queueOpen = true
        player.settingsPage = "video"
        player.minimalView = true
        verify(!player.topVisible)
        verify(!player.bottomVisible)
        verify(!player.libraryOpen)
        verify(!player.queueOpen)
        verify(!findChild(player, "resumePlaybackPrompt").visible)
        verify(!findChild(player, "playbackStatisticsOverlay").visible)
        compare(player.settingsPage, "")
        const viewport = findChild(player, "redesignViewport")
        compare(Qt.rect(viewport.x, viewport.y, viewport.width, viewport.height), Qt.rect(0, 0, player.width, player.height))
        player.revealControls()
        verify(!player.topVisible)
        verify(!player.bottomVisible)
        player.minimalView = false
        verify(player.topVisible)
        verify(player.bottomVisible)
        player.resumeAvailable = false
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
    function test_fullscreenTimelineBoundaryDoesNotFlicker_data() {
        return [{tag: "plain", videoHover: false}, {tag: "video-surface-hover", videoHover: true}]
    }
    function test_fullscreenTimelineBoundaryDoesNotFlicker(data) {
        consumeVideoHover = data.videoHover
        player.fullscreen = true
        player.forceActiveFocus()
        mouseMove(player, player.width / 2, player.height / 2)
        wait(1900)
        verify(!player.bottomVisible)
        const seek = findChild(player, "seekBar")
        verify(seek)
        mouseMove(player, player.width / 2, player.height - 2)
        tryCompare(player, "bottomVisible", true)
        toolbarVisibilitySpy.clear()
        for (let i = 0; i < 20; ++i) {
            mouseMove(seek, seek.width / 2, -1)
            wait(10)
            mouseMove(seek, seek.width / 2, 1)
            wait(10)
            mouseMove(seek, seek.width / 2, seek.height - 1)
            wait(10)
            mouseMove(seek, seek.width / 2, seek.height + 1)
            wait(10)
        }
        compare(toolbarVisibilitySpy.count, 0)
        verify(player.bottomVisible)
        mouseClick(findChild(player, "playButton"))
        verify(player.playing)
        player.forceActiveFocus()
        mouseMove(player, player.width / 2, player.height / 2)
        tryCompare(player, "bottomVisible", false)
    }
}
