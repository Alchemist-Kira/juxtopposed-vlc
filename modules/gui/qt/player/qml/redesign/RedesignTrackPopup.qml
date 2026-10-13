// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C
import VLC.Player
import VLC.Dialogs

C.Popup {
    id: root
    property real scaleFactor: 1
    property bool lightTheme: false
    property string page: "subtitles"
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme }
    signal preferencesRequested(string page)
    width: Math.min(parent.width - theme.dp(24), theme.dp(400))
    height: Math.min(parent.height - theme.dp(100), theme.dp(460))
    padding: theme.dp(20)
    focus: true
    background: Rectangle { color: theme.panel; radius: theme.dp(10); border.color: theme.border }
    function select(model, index, selected) { model.setData(model.index(index, 0), selected, Qt.CheckStateRole) }
    ColumnLayout {
        anchors.fill: parent
        spacing: theme.dp(16)
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [{key: "video", label: qsTr("Video"), icon: "video"}, {key: "audio", label: qsTr("Audio"), icon: "audio"}, {key: "subtitles", label: qsTr("Subtitles"), icon: "subtitles"}]
                RedesignButton {
                    required property var modelData
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                    text: modelData.label; caption: root.width > theme.dp(360) ? text : ""; iconName: modelData.icon
                    selected: root.page === modelData.key
                    onClicked: root.page = modelData.key
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
                RedesignTracks {
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                    heading: qsTr("Embedded tracks")
                    trackModel: root.page === "video" ? Player.videoTracks : root.page === "audio" ? Player.audioTracks : Player.subtitleTracks
                    allowDisable: root.page === "subtitles"
                    onSelectionRequested: (index, selected) => root.select(trackModel, index, selected)
                    onDisableRequested: { for (let i = 0; i < Player.subtitleTracks.count; ++i) root.select(Player.subtitleTracks, i, false) }
                }
                RedesignTracks {
                    Layout.fillWidth: true
                    visible: root.page === "audio"
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                    heading: qsTr("Output device"); trackModel: Player.audioDevices
                    onSelectionRequested: (index, selected) => root.select(trackModel, index, selected)
                }
                RedesignButton {
                    visible: root.page === "subtitles"
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                    iconName: "add"; caption: qsTr("Add subtitle file"); text: caption
                    onClicked: DialogsProvider.loadSubtitlesFile()
                }
            }
        }
        RedesignButton {
            Layout.fillWidth: true
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
            caption: qsTr("Show preferences"); text: caption
            onClicked: { root.close(); root.preferencesRequested(root.page) }
        }
    }
}
