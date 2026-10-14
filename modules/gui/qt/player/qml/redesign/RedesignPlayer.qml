// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import VLC.MainInterface
import VLC.Player
import VLC.Playlist
import VLC.Style
import VLC.Util
import VLC.Dialogs
import VLC.Menus as Menus
import VLC.Widgets as Widgets

FocusScope {
    id: rootPlayer
    property var pagePrefix: []
    readonly property real positionSliderY: view.positionSliderY
    readonly property ColorContext colorContext: ColorContext { palette: VLCStyle.palette; colorSet: ColorContext.Window }
    property bool resumeAvailable: false
    Connections {
        target: Player
        function onInputChanged() { view.refreshSeekPreview() }
    }
    function clockText(tick) {
        if (!tick.valid()) return "00:00:00"
        const parts = tick.formatHMS(0).split(":")
        return parts.length === 2 ? "00:" + parts.join(":") : parts.join(":")
    }
    RedesignSleepTimer { id: sleepTimer; onTriggered: MainPlaylistController.pause() }
    RedesignPreferences { id: playerPreferences; ctx: MainCtx; autoSave: true; editPlayerPreset: true }
    Shortcut {
        sequences: { playerPreferences.revision; return String(playerPreferences.value("key-toggle-library") || "").split("\t").filter(sequence => sequence.length > 0) }
        context: Qt.WindowShortcut
        enabled: MainCtx.useGlobalShortcuts
        onActivated: { view.libraryOpen = !view.libraryOpen; view.libraryExpanded = false }
    }
    Binding {
        target: MainCtx
        property: "preferHotkeys"
        value: !view.controlsLocked && !tracksPopup.visible && !mediaMenu.visible
        restoreMode: Binding.RestoreBindingOrValue
    }

    Component.onCompleted: {
        MainCtx.playqueuePanel.docked = true
    }

    RedesignPlayerView {
        id: view
        objectName: "redesignPlayer"
        anchors.fill: parent
        focus: true
        scaleFactor: VLCStyle.scale
        lightTheme: !VLCStyle.palette.isDark
        accentColor: MainCtx.redesignAccent
        playing: Player.playingState === Player.PLAYING_STATE_PLAYING
        started: Player.isStarted
        hasVideo: MainCtx.hasEmbededVideo
        seekable: Player.seekable
        pausable: Player.pausable
        hasPrevious: MainPlaylistController.hasPrev
        hasNext: MainPlaylistController.hasNext
        muted: Player.muted
        fullscreen: MainCtx.intfMainWindow.visibility === Window.FullScreen
        autoHideMode: MainCtx.redesignPlayerPreferences.autoHide
        controlsHideTimeout: MainCtx.redesignPlayerPreferences.hideTimeout
        showFullscreenControls: MainCtx.redesignPlayerPreferences.fullscreenControls
        maximized: MainCtx.intfMainWindow.visibility === Window.Maximized
        showWindowButtons: MainCtx.clientSideDecoration && !fullscreen
        position: Player.position
        volume: Player.volume
        maxVolume: MainCtx.maxVolume / 100
        buffering: Player.buffering
        statistics: Player.playbackStatistics
        mediaTitle: Player.title || Player.name || qsTr("VLC Media Player")
        locationTitle: view.libraryItem ? view.libraryItem.heading : qsTr("Videos")
        timeText: rootPlayer.clockText(Player.time)
        lengthText: rootPlayer.clockText(Player.length)
        artist: Player.artist
        artwork: Player.artwork
        resumeAvailable: rootPlayer.resumeAvailable
        timeForPosition: value => rootPlayer.clockText(Player.length.scale(value))
        seekPreviewImage: Player.seekPreview
        seekPreviewImagePosition: Player.seekPreviewPosition
        onSeekPreviewRequested: value => Player.requestSeekPreview(value)
        onSeekPreviewEnded: Player.cancelSeekPreview()
        onTogglePlayback: MainPlaylistController.empty ? DialogsProvider.simpleOpenDialog() : MainPlaylistController.togglePlayPause()
        onPrevious: MainPlaylistController.prevOrReset()
        onNext: MainPlaylistController.next()
        onSeekRequested: value => Player.jumpToPos(value)
        onVolumeRequested: value => { Player.muted = false; Player.volume = value }
        onMuteRequested: Player.muted = !Player.muted
        onFullscreenRequested: MainCtx.toggleInterfaceFullScreen()
        onMinimizeRequested: MainCtx.requestInterfaceMinimized()
        onMaximizeRequested: maximized ? MainCtx.requestInterfaceNormal() : MainCtx.requestInterfaceMaximized()
        onCloseRequested: DialogsProvider.quit()
        onOpenRequested: DialogsProvider.simpleOpenDialog()
        onPreferencesRequested: DialogsProvider.prefsDialog()
        onFullLibraryRequested: { libraryOpen = true; libraryExpanded = !libraryExpanded }
        onAudioTracksRequested: anchor => openTracks(anchor, "audio")
        onSubtitleTracksRequested: anchor => openTracks(anchor, "subtitles")
        function openTracks(anchor, page) {
            settingsPage = ""
            queueOpen = false
            tracksPopup.page = page
            tracksPopup.x = Math.max(0, Math.min(anchor.mapToItem(view, 0, 0).x, view.width - tracksPopup.width - view.theme.dp(20)))
            tracksPopup.y = Math.max(view.theme.dp(40), view.positionSliderY - tracksPopup.height - view.theme.dp(20))
            tracksPopup.open()
        }
        onMenuRequested: anchor => {
            const point = anchor.mapToItem(view, 0, anchor.height)
            mediaMenu.x = Math.min(point.x, view.width - mediaMenu.width)
            mediaMenu.y = point.y
            mediaMenu.open()
        }
        onResumeRequested: resume => {
            rootPlayer.resumeAvailable = false
            if (resume) Player.restorePlaybackPos()
            else Player.acknowledgeRestoreCallback()
        }
        onKeyPressed: event => {
            if (!event.accepted && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)
                MainCtx.sendHotkey(event.key, event.modifiers)
        }
        titleBarDragContent: Component {
            Loader {
                active: MainCtx.clientSideDecoration && !view.fullscreen
                source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"
            }
        }
        videoContent: Component {
            VideoSurface {
                id: video
                videoSurfaceProvider: MainCtx.videoSurfaceProvider
                // Clear the chrome background where the compositor displays video.
                renderingEnabled: true
                visible: MainCtx.hasEmbededVideo
                focus: visible
                cursorShape: view.fullscreen && !view.topVisible && !view.bottomVisible ? Qt.BlankCursor : Qt.ArrowCursor
            }
        }
        Connections {
            target: MainCtx.playqueuePanel
            function onVisibleChanged() { view.queueOpen = MainCtx.playqueuePanel.visible && MainCtx.playqueuePanel.docked }
        }
        onQueueOpenChanged: if (MainCtx.playqueuePanel.docked) MainCtx.playqueuePanel.visible = queueOpen
        libraryContent: Component {
            Loader {
                source: MainCtx.mediaLibraryAvailable ? "qrc:///qt/qml/VLC/Player/RedesignLibrary.qml" : ""
                onLoaded: {
                    item.scaleFactor = Qt.binding(() => view.scaleFactor)
                    item.lightTheme = Qt.binding(() => view.lightTheme)
                    item.accentColor = Qt.binding(() => view.accentColor)
                    item.fullLibraryRequested.connect(() => { view.libraryExpanded = !view.libraryExpanded })
                }
                RedesignLibraryView {
                    anchors.fill: parent
                    visible: !MainCtx.mediaLibraryAvailable
                    scaleFactor: view.scaleFactor; lightTheme: view.lightTheme; accentColor: view.accentColor
                    emptyText: qsTr("This VLC build has no media library. Open files or a folder to add them to the queue.")
                    onAddRequested: DialogsProvider.simpleOpenDialog()
                    onCategoryRequested: category => category === 3 ? DialogsProvider.openNetDialog() : DialogsProvider.simpleOpenDialog()
                }
                property string heading: item ? item.heading : qsTr("Videos")
            }
        }
        queueContent: Component {
            RedesignQueuePanel {
                scaleFactor: view.scaleFactor; lightTheme: view.lightTheme; accentColor: view.accentColor
                queueContent: Component { RedesignQueue {
                scaleFactor: view.scaleFactor; lightTheme: view.lightTheme; accentColor: view.accentColor
                queueModel: PlaylistListModel { id: queueModel; playlist: MainPlaylistController.playlist }
                itemCount: MainPlaylistController.count
                random: MainPlaylistController.random
                repeating: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                onCloseRequested: view.queueOpen = false
                onAddRequested: DialogsProvider.simpleOpenDialog(false)
                onSaveRequested: DialogsProvider.savePlayingToPlaylist()
                onClearRequested: MainPlaylistController.clear()
                onShuffleRequested: MainPlaylistController.toggleRandom()
                onRepeatRequested: MainPlaylistController.toggleRepeatMode()
                onPlayRequested: index => MainPlaylistController.goTo(index, true)
                onRemoveRequested: index => queueModel.removeItems([index])
                onMoveRequested: (from, to) => queueModel.moveItemsPre([from], to)
                onLibraryDropRequested: source => source.libraryView.enqueueRequested(source.mediaIndex)
                } }
            }
        }
        settingsContent: Component {
            RedesignSettings {
                preferenceStore: playerPreferences
                Component.onCompleted: playerPreferences.refresh()
                scaleFactor: view.scaleFactor; lightTheme: view.lightTheme; accentColor: view.accentColor
                page: view.settingsPage
                showStatistics: view.showStatistics
                sleepTimerMinutes: sleepTimer.minutes
                onStatisticsRequested: enabled => view.showStatistics = enabled
                onPageRequested: page => view.settingsPage = page
                onCloseRequested: view.settingsPage = ""
                onSleepTimerRequested: minutes => sleepTimer.start(minutes)
            }
        }
    }

    RedesignTrackPopup {
        id: tracksPopup
        parent: view
        scaleFactor: view.scaleFactor; lightTheme: view.lightTheme; accentColor: view.accentColor
        videoTracks: Player.videoTracks
        audioTracks: Player.audioTracks
        subtitleTracks: Player.subtitleTracks
        audioDevices: Player.audioDevices
        onSelectionRequested: (model, index, selected) => model.setData(model.index(index, 0), selected, Qt.CheckStateRole)
        onDisableRequested: model => {
            for (let i = 0; i < model.count; ++i)
                model.setData(model.index(i, 0), false, Qt.CheckStateRole)
        }
        onAddSubtitleFileRequested: DialogsProvider.loadSubtitlesFile()
        onPreferencesRequested: page => view.settingsPage = page
    }

    RedesignMenu {
        id: mediaMenu
        parent: view
        scaleFactor: view.scaleFactor; lightTheme: view.lightTheme; accentColor: view.accentColor
        onActionRequested: action => {
            switch (action) {
            case "file": DialogsProvider.simpleOpenDialog(); break
            case "subtitles": DialogsProvider.loadSubtitlesFile(); break
            case "directory": DialogsProvider.PLOpenDir(); break
            case "disc": DialogsProvider.openDiscDialog(); break
            case "network": DialogsProvider.openNetDialog(); break
            case "capture": DialogsProvider.openCaptureDialog(); break
            case "convert": DialogsProvider.openAndTranscodingDialogs(); break
            case "stream": DialogsProvider.openAndStreamingDialogs(); break
            case "library": view.libraryOpen = true; view.libraryExpanded = true; break
            case "customize": DialogsProvider.showToolbarEditorDialog(); break
            case "settings": DialogsProvider.prefsDialog(); break
            case "advanced": globalMenu.popup(view.mapToGlobal(0, view.theme.dp(40))); break
            case "about": DialogsProvider.aboutDialog(); break
            }
        }
    }
    Menus.QmlGlobalMenu { id: globalMenu; ctx: MainCtx }
    // VideoSurface continues to provide VLC's native context menu and hotkeys.
    QmlAudioContextMenu { id: audioContextMenu; ctx: MainCtx }
    TapHandler {
        enabled: !MainCtx.hasEmbededVideo
        acceptedButtons: Qt.RightButton
        onTapped: point => audioContextMenu.popup(point.globalPosition)
    }
    Connections {
        target: MainCtx
        function onAskShow() { view.revealControls() }
        function onMainInterfaceModesChanged() {
            if (!MainCtx.playerView && Player.isStarted) { view.libraryOpen = true; view.libraryExpanded = true }
        }
    }
    Connections {
        target: Player
        function onPlaybackRestoreQueried() { rootPlayer.resumeAvailable = Player.canRestorePlayback }
    }
    Dialogs {
        z: 10
        bgContent: rootPlayer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: view.theme.dp(54) }
    }
    Widgets.FloatingNotification {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: view.theme.dp(20); bottomMargin: view.theme.dp(74) }
    }
}
