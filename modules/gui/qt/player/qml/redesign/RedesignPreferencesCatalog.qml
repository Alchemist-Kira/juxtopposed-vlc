// SPDX-License-Identifier: GPL-2.0-or-later
import QtQml

QtObject {
    // The simple view follows the supplied Figma screens. The advanced view is
    // populated from this build's native configuration catalog.
    readonly property var sections: ({
        general: [
            { title: qsTr("Startup"), rows: [
                ["qt-error-dialogs", qsTr("Show error notifications")],
                ["qt-updates-notif", qsTr("Automatically check for updates")],
                ["qt-updates-days", qsTr("Check for updates every (days)")] ] },
            { title: qsTr("Diagnostics"), rows: [
                ["qt-verbose", qsTr("Developer mode")], ["logfile", qsTr("Log file")],
                ["verbose", qsTr("Verbosity")], ["stats", qsTr("Collect statistics")] ] } ],
        interface: [
            { title: qsTr("Window"), rows: [
                ["embedded-video", qsTr("Play video inside main window")],
                ["qt-video-autoresize", qsTr("Resize window to fit video")],
                ["video-on-top", qsTr("Keep window above other windows")],
                ["qt-titlebar", qsTr("Show window decorations")],
                ["qt-name-in-title", qsTr("Show the file name in the title bar")],
                ["qt-fullscreen-screennumber", qsTr("Fullscreen screen (-1 = current)")] ] },
            { title: qsTr("Playback Controls"), rows: [
                ["qt-minimal-view", qsTr("Start in compact mode")],
                ["mouse-hide-timeout", qsTr("Hide cursor after (ms)")],
                ["qt-fs-controller", qsTr("Show controls in fullscreen")] ] },
            { title: qsTr("Notifications and System Tray"), rows: [
                ["qt-system-tray", qsTr("Show a system tray icon")],
                ["qt-start-minimized", qsTr("Start minimized to the tray")],
                ["qt-notification", qsTr("Show a popup when the track changes")],
                ["qt-close-to-system-tray", qsTr("Close to the system tray")] ] },
            { title: qsTr("Additional Options"), rows: [
                ["qt-opacity", qsTr("Window opacity")],
                ["qt-pause-minimized", qsTr("Pause video when minimized")],
                ["qt-auto-raise", qsTr("Bring VLC to the front when playback starts")],
                ["qt-embedded-open", qsTr("Show file browser inside the open dialog")],
                ["qt-icon-change", qsTr("Allow the app icon to change")],
                ["qt-fs-opacity", qsTr("Fullscreen controls opacity")],
                ["qt-fs-sensitivity", qsTr("Fullscreen controls sensitivity")] ] } ],
        privacy: [
            { title: qsTr("History"), rows: [
                ["save-recentplay", qsTr("Save recently played items")],
                ["restore-playback-pos", qsTr("Remember playback position")],
                ["restore-playback-states", qsTr("Remember playback settings")] ] },
            { title: qsTr("Network Access"), rows: [
                ["metadata-network-access", qsTr("Allow fetching metadata from the internet")],
                ["lastfm-username", qsTr("Last.fm username")], ["lastfm-password", qsTr("Last.fm password")] ] } ],
        controls: [
            { title: qsTr("Skip Durations"), rows: [
                ["extrashort-jump-size", qsTr("Very short jump (seconds)")],
                ["short-jump-size", qsTr("Short jump (seconds)")],
                ["medium-jump-size", qsTr("Medium jump (seconds)")],
                ["long-jump-size", qsTr("Long jump (seconds)")] ] },
            { title: qsTr("Mouse"), rows: [
                ["mouse-pause-policy", qsTr("Click to play or pause")],
                ["hotkeys-y-wheel-mode", qsTr("Vertical mouse wheel")],
                ["hotkeys-x-wheel-mode", qsTr("Horizontal mouse wheel")] ] },
            { title: qsTr("Keyboard Shortcuts"), rows: [
                ["key-play-pause", qsTr("Play / Pause")], ["key-stop", qsTr("Stop")],
                ["key-next", qsTr("Next track")], ["key-prev", qsTr("Previous track")],
                ["key-fullscreen", qsTr("Fullscreen")], ["key-vol-up", qsTr("Volume up")],
                ["key-vol-down", qsTr("Volume down")], ["key-vol-mute", qsTr("Mute")] ] } ],
        playback: [
            { title: qsTr("Playback"), rows: [
                ["restore-playback-pos", qsTr("Continue playback")], ["playlist-autostart", qsTr("Start playing automatically")],
                ["rate", qsTr("Default playback speed")] ] },
            { title: qsTr("Tracks"), rows: [
                ["preferred-resolution", qsTr("Preferred video quality")], ["menu-language", qsTr("Menu language")],
                ["audio-language", qsTr("Audio language")], ["audio-track", qsTr("Audio track")],
                ["sub-language", qsTr("Subtitle language")], ["sub-track", qsTr("Subtitle track")] ] },
            { title: qsTr("Queue"), rows: [
                ["repeat", qsTr("Repeat current media")], ["loop", qsTr("Repeat the queue")],
                ["random", qsTr("Shuffle")], ["play-and-stop", qsTr("Stop after the current item")],
                ["play-and-exit", qsTr("Quit after playback")], ["play-and-pause", qsTr("Pause on the last frame")] ] } ],
        video: [
            { title: qsTr("Video"), rows: [ ["video", qsTr("Enable video")], ["fullscreen", qsTr("Start in fullscreen")],
                ["drop-late-frames", qsTr("Drop late frames")], ["skip-frames", qsTr("Skip frames")],
                ["deinterlace", qsTr("Deinterlacing")], ["deinterlace-mode", qsTr("Deinterlacing mode")] ] },
            { title: qsTr("Snapshots"), rows: [ ["snapshot-path", qsTr("Save snapshots to")],
                ["snapshot-prefix", qsTr("File name prefix")], ["snapshot-format", qsTr("Image format")],
                ["snapshot-preview", qsTr("Show snapshot preview")], ["snapshot-sequential", qsTr("Sequential numbering")] ] } ],
        audio: [
            { title: qsTr("Audio"), rows: [ ["audio", qsTr("Enable audio")], ["aout", qsTr("Output module")],
                ["volume-save", qsTr("Remember volume")], ["audio-time-stretch", qsTr("Time stretching")],
                ["audio-language", qsTr("Preferred language")], ["audio-desync", qsTr("Default audio delay (ms)")] ] },
            { title: qsTr("Volume"), rows: [ ["qt-max-volume", qsTr("Maximum volume (%)")], ["volume-step", qsTr("Volume step")],
                ["audio-replay-gain-mode", qsTr("Replay gain")], ["audio-replay-gain-preamp", qsTr("Replay gain preamp")],
                ["audio-replay-gain-peak-protection", qsTr("Protect against clipping")] ] } ],
        subtitles: [
            { title: qsTr("Subtitles"), rows: [ ["spu", qsTr("Enable subtitles")], ["sub-language", qsTr("Preferred language")],
                ["subsdec-encoding", qsTr("Text encoding")], ["sub-autodetect-file", qsTr("Automatically detect subtitle files")],
                ["sub-autodetect-fuzzy", qsTr("Detection strictness")], ["sub-delay", qsTr("Default delay (tenths of a second)")] ] },
            { title: qsTr("Appearance"), rows: [ ["freetype-font", qsTr("Font")], ["freetype-rel-fontsize", qsTr("Relative font size")],
                ["freetype-bold", qsTr("Bold")], ["freetype-color", qsTr("Text color (RGB)")], ["freetype-opacity", qsTr("Text opacity")],
                ["freetype-outline-thickness", qsTr("Outline thickness")], ["freetype-shadow-opacity", qsTr("Shadow opacity")],
                ["sub-margin", qsTr("Vertical position")] ] } ],
        library: [ { title: qsTr("Library"), rows: [ ["save-recentplay", qsTr("Save recently played items")],
                ["recursive", qsTr("Include subfolders")], ["ignore-filetypes", qsTr("Ignore file types")] ] } ],
        network: [ { title: qsTr("Network"), rows: [ ["http-proxy", qsTr("HTTP proxy")], ["http-proxy-pwd", qsTr("Proxy password")],
                ["http-reconnect", qsTr("Reconnect automatically")], ["network-caching", qsTr("Network caching (ms)")],
                ["http-user-agent", qsTr("User agent")], ["ipv4-timeout", qsTr("Connection timeout (ms)")] ] } ],
        performance: [ { title: qsTr("Decoding and Caching"), rows: [ ["avcodec-hw", qsTr("Hardware decoding")],
                ["avcodec-threads", qsTr("Decoder threads (0 = automatic)")], ["file-caching", qsTr("File caching (ms)")],
                ["disc-caching", qsTr("Disc caching (ms)")], ["live-caching", qsTr("Live capture caching (ms)")],
                ["network-caching", qsTr("Network caching (ms)")] ] } ],
        recording: [ { title: qsTr("Recording"), rows: [ ["input-record-path", qsTr("Save recordings to")],
                ["input-record-native", qsTr("Use the original format")] ] } ],
        extensions: [ { title: qsTr("Extensions"), rows: [ ["qt-autoload-extensions", qsTr("Load extensions automatically")] ] } ]
    })
}
