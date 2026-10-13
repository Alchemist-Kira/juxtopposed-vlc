// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C
import VLC.Player
import VLC.Playlist
import VLC.Dialogs

C.Pane {
    id: root
    padding: 0
    palette.window: theme.panel
    palette.base: theme.field
    palette.text: theme.foreground
    palette.button: theme.background
    palette.buttonText: theme.bright
    palette.highlight: theme.accent
    palette.highlightedText: "#161616"
    background: Rectangle { color: theme.panel }
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property string page: "playback"
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal pageRequested(string page)
    signal closeRequested()
    signal sleepTimerRequested(int minutes)

    function select(model, index, selected) { model.setData(model.index(index, 0), selected, Qt.CheckStateRole) }
    function disable(model) { for (let i = 0; i < model.rowCount(); ++i) select(model, i, false) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; height: theme.dp(50); color: theme.field
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: theme.dp(8); anchors.rightMargin: theme.dp(8)
                spacing: 0
                Repeater {
                    model: [{key: "playback", icon: "play", label: qsTr("Playback")}, {key: "video", icon: "video", label: qsTr("Video")}, {key: "audio", icon: "audio", label: qsTr("Audio")}, {key: "subtitles", icon: "subtitles", label: qsTr("Subtitles")}]
                    RedesignButton {
                        required property var modelData
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        iconSize: theme.dp(18)
                        iconName: modelData.icon; text: modelData.label
                        caption: root.width > theme.dp(360) ? modelData.label : ""
                        selected: root.page === modelData.key
                        onClicked: root.pageRequested(modelData.key)
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: theme.dp(2); color: theme.accent; visible: root.page === modelData.key }
                    }
                }
            }
        }
        C.ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: theme.dp(20)
                // Padding belongs to the content so the background is uninterrupted.
                Item { Layout.fillWidth: true; height: 0 }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    spacing: theme.dp(22)
                    visible: root.page === "playback"
                    RedesignSettingSlider {
                        objectName: "playbackRateControl"
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        label: qsTr("Speed"); suffix: "×"; decimals: 2
                        from: 0.25; to: 2; stepSize: 0.05
                        currentValue: Player.rate; enabled: Player.ratechangable
                        onMoved: value => Player.rate = value
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Reverse"); text: caption; enabled: Player.rewindable; onClicked: Player.reverse() }
                        RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Next frame"); text: caption; enabled: Player.hasVideoOutput; onClicked: Player.frameNext() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: qsTr("Sleep timer"); color: theme.foreground; font.pixelSize: theme.dp(14) }
                        C.ComboBox {
                            model: [qsTr("Off"), qsTr("15 minutes"), qsTr("30 minutes"), qsTr("60 minutes"), qsTr("90 minutes")]
                            onActivated: index => root.sleepTimerRequested([0, 15, 30, 60, 90][index])
                        }
                    }
                    RedesignTracks {
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        heading: qsTr("Audio visualizer"); trackModel: Player.audioVisualization
                        onSelectionRequested: (index, selected) => root.select(trackModel, index, selected)
                    }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Media information and statistics"); text: caption; onClicked: DialogsProvider.mediaInfoDialog() }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Stop playback"); text: caption; iconName: "stop"; onClicked: MainPlaylistController.stop() }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    spacing: theme.dp(22)
                    visible: root.page === "audio"
                    RedesignTracks { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; heading: qsTr("Audio tracks"); trackModel: Player.audioTracks; onSelectionRequested: (index, selected) => root.select(trackModel, index, selected) }
                    RedesignTracks { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; heading: qsTr("Output device"); trackModel: Player.audioDevices; onSelectionRequested: (index, selected) => root.select(trackModel, index, selected) }
                    Rectangle { Layout.fillWidth: true; height: theme.dp(1); color: theme.border }
                    Text { text: qsTr("Synchronization"); color: theme.bright; font.pixelSize: theme.dp(16) }
                    RedesignSettingSlider {
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        label: qsTr("Audio track delay"); suffix: " s"; decimals: 3
                        resetValue: 0
                        from: -10; to: 10; stepSize: 0.05
                        currentValue: Player.audioDelayMS / 1000
                        onMoved: value => Player.audioDelayMS = Math.round(value * 1000)
                    }
                    Rectangle { Layout.fillWidth: true; height: theme.dp(1); color: theme.border }
                    RedesignTracks { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; heading: qsTr("Stereo mode"); trackModel: Player.audioStereoMode; onSelectionRequested: (index, selected) => root.select(trackModel, index, selected) }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Equalizer and audio filters"); text: caption; onClicked: DialogsProvider.extendedDialog() }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    spacing: theme.dp(22)
                    visible: root.page === "subtitles"
                    RedesignTracks { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; heading: qsTr("Subtitle tracks"); trackModel: Player.subtitleTracks; allowDisable: true; onSelectionRequested: (index, selected) => root.select(trackModel, index, selected); onDisableRequested: root.disable(trackModel) }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "add"; caption: qsTr("Add subtitle file"); text: caption; onClicked: DialogsProvider.loadSubtitlesFile() }
                    Rectangle { Layout.fillWidth: true; height: theme.dp(1); color: theme.border }
                    Text { text: qsTr("Synchronization"); color: theme.bright; font.pixelSize: theme.dp(16) }
                    RedesignSettingSlider {
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        label: qsTr("Subtitle track delay"); suffix: " s"; decimals: 3
                        resetValue: 0
                        from: -10; to: 10; stepSize: 0.05
                        currentValue: Player.subtitleDelayMS / 1000
                        onMoved: value => Player.subtitleDelayMS = Math.round(value * 1000)
                    }
                    RedesignSettingSlider {
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        objectName: "subtitleFPSControl"
                        label: qsTr("Subtitle Speed"); suffix: " fps"; decimals: 3
                        from: 0; to: 60; stepSize: 0.001
                        resetValue: 0; minimumValueText: qsTr("Automatic")
                        currentValue: Player.subtitleFPS
                        onMoved: value => Player.subtitleFPS = value
                    }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Subtitle font, size and appearance"); text: caption; onClicked: DialogsProvider.prefsDialog() }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    spacing: theme.dp(22)
                    visible: root.page === "video"
                    Repeater {
                        model: [{label: qsTr("Video tracks"), choices: Player.videoTracks}, {label: qsTr("Zoom"), choices: Player.zoom}, {label: qsTr("Aspect ratio"), choices: Player.aspectRatio}, {label: qsTr("Crop"), choices: Player.crop}, {label: qsTr("Deinterlace"), choices: Player.deinterlace}]
                        RedesignTracks {
                            required property var modelData
                            Layout.fillWidth: true
                            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                            heading: modelData.label; trackModel: modelData.choices
                            onSelectionRequested: (index, selected) => root.select(trackModel, index, selected)
                        }
                    }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Snapshot"); text: caption; enabled: Player.hasVideoOutput; onClicked: Player.snapshot() }
                    RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Video effects and filters"); text: caption; onClicked: DialogsProvider.extendedDialog() }
                }
                Item { height: theme.dp(20) }
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: theme.dp(64); color: theme.panel
            border.color: theme.border
            RowLayout {
                anchors.fill: parent; anchors.margins: theme.dp(12)
                RedesignButton { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "settings"; caption: qsTr("Advanced settings"); text: caption; onClicked: DialogsProvider.prefsDialog() }
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "close"; text: qsTr("Close settings"); onClicked: root.closeRequested() }
            }
        }
    }
}
