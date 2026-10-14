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
    property bool showStatistics: false
    property int sleepTimerMinutes: 0
    required property var preferenceStore
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal pageRequested(string page)
    signal closeRequested()
    signal sleepTimerRequested(int minutes)
    signal statisticsRequested(bool enabled)

    function select(model, index, selected) { model.setData(model.index(index, 0), selected, Qt.CheckStateRole) }
    function disable(model) { for (let i = 0; i < model.rowCount(); ++i) select(model, i, false) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; height: theme.dp(50); color: theme.field
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: theme.dp(14); anchors.rightMargin: theme.dp(14)
                spacing: theme.dp(14)
                Repeater {
                    model: [{key: "playback", icon: "play", label: qsTr("Playback")}, {key: "video", icon: "video", label: qsTr("Video")}, {key: "audio", icon: "audio", label: qsTr("Audio")}, {key: "subtitles", icon: "subtitles", label: qsTr("Subtitles")}]
                    RedesignButton {
                        required property var modelData
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        Layout.fillHeight: true
                        captionFontSize: 12; iconSize: theme.dp(16)
                        selectedForeground: theme.foreground
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; border.width: parent.visualFocus ? 1 : 0; border.color: theme.accent }
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
                spacing: 0
                Item { Layout.fillWidth: true; height: theme.dp(11) }
                RedesignPlaybackSettings {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    visible: root.page === "playback"
                    showStatistics: root.showStatistics
                    sleepTimerMinutes: root.sleepTimerMinutes
                    playbackRate: Player.rate; rateAvailable: Player.ratechangable
                    reversed: Player.rate < 0; reverseAvailable: Player.rewindable && Player.ratechangable
                    visualizationModel: Player.audioVisualization
                    onStatisticsRequested: enabled => root.statisticsRequested(enabled)
                    onReverseRequested: reversed => Player.rate = (reversed ? -1 : 1) * Math.abs(Player.rate)
                    onRateRequested: value => Player.rate = (Player.rate < 0 ? -1 : 1) * value
                    onSleepTimerRequested: minutes => root.sleepTimerRequested(minutes)
                    onVisualizationRequested: index => root.select(Player.audioVisualization, index, true)
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    spacing: theme.dp(22)
                    visible: root.page === "audio"
                    Layout.topMargin: theme.dp(11)
                    RedesignTrackDefaults { Layout.fillWidth: true; backend: root.preferenceStore; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
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
                    Layout.topMargin: theme.dp(11)
                    RedesignTrackDefaults { Layout.fillWidth: true; subtitles: true; backend: root.preferenceStore; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
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
        RowLayout {
            visible: root.preferenceStore.errorMessage.length > 0
            Layout.fillWidth: true; Layout.margins: theme.dp(12)
            Text { Layout.fillWidth: true; text: root.preferenceStore.errorMessage; wrapMode: Text.WordWrap; color: theme.danger; font.pixelSize: theme.dp(12) }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Retry"); text: caption; onClicked: root.preferenceStore.save() }
        }
        Rectangle {
            visible: root.page !== "playback"
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
