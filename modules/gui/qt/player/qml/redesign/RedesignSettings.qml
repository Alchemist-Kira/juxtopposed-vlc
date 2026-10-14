// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
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
                RedesignAudioSettings {
                    Layout.fillWidth: true; Layout.leftMargin: theme.dp(24); Layout.rightMargin: theme.dp(24)
                    visible: root.page === "audio"
                    Layout.topMargin: theme.dp(11)
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    backend: root.preferenceStore
                    stereoModel: Player.audioStereoMode
                    audioDelaySeconds: {
                        root.preferenceStore.revision
                        return Player.isStarted && !root.preferenceStore.isStaged("audio-desync") ? Player.audioDelayMS / 1000 : Number(root.preferenceStore.value("audio-desync")) / 1000
                    }
                    onStereoRequested: index => {
                        const value = Player.audioStereoMode.choiceValue(index)
                        if (value !== undefined) root.preferenceStore.stage("stereo-mode", value)
                    }
                    onDelayRequested: seconds => root.preferenceStore.stage("audio-desync", Math.round(seconds * 1000))
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
                        from: -10; to: 10; inputFrom: -2147483.648; inputTo: 2147483.647; stepSize: 0.05
                        currentValue: {
                            root.preferenceStore.revision
                            return Player.isStarted && !root.preferenceStore.isStaged("redesign-subtitle-delay") ? Player.subtitleDelayMS / 1000 : Number(root.preferenceStore.value("redesign-subtitle-delay")) / 1000
                        }
                        onMoved: value => root.preferenceStore.stage("redesign-subtitle-delay", Math.round(value * 1000))
                    }
                    RedesignSettingSlider {
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        objectName: "subtitleFPSControl"
                        label: qsTr("Subtitle Speed"); suffix: " fps"; decimals: 3
                        from: 0; to: 60; stepSize: 0.001
                        resetValue: 0; minimumValueText: qsTr("Automatic")
                        currentValue: {
                            root.preferenceStore.revision
                            return Player.isStarted && !root.preferenceStore.isStaged("sub-fps") ? Player.subtitleFPS : Number(root.preferenceStore.value("sub-fps"))
                        }
                        onMoved: value => root.preferenceStore.stage("sub-fps", value)
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
            Layout.fillWidth: true; height: theme.dp(125); color: theme.panel
            Rectangle { anchors.top: parent.top; width: parent.width; height: theme.dp(1); color: theme.border }
            ColumnLayout {
                anchors.fill: parent; anchors.leftMargin: theme.dp(20); anchors.rightMargin: theme.dp(20); anchors.topMargin: theme.dp(20); anchors.bottomMargin: theme.dp(12)
                spacing: theme.dp(14)
                RedesignPlayerPreset { Layout.fillWidth: true; backend: root.preferenceStore; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
                RedesignButton { Layout.alignment: Qt.AlignHCenter; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "settings"; iconSize: theme.dp(20); caption: qsTr("Open Advanced Settings"); text: caption; onClicked: DialogsProvider.prefsDialog() }
            }
        }
    }
}
