// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

C.Popup {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property string page: "subtitles"
    property var videoTracks
    property var audioTracks
    property var subtitleTracks
    property var audioDevices
    readonly property var currentTracks: page === "video" ? videoTracks : page === "audio" ? audioTracks : subtitleTracks
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal preferencesRequested(string page)
    signal selectionRequested(var model, int index, bool selected)
    signal disableRequested(var model)
    signal addSubtitleFileRequested()
    width: Math.min(parent.width - theme.dp(24), theme.dp(400))
    height: Math.min(parent.height - theme.dp(114), theme.dp(524))
    padding: 0
    focus: true
    background: Rectangle { color: theme.panel; radius: theme.dp(10); border.color: theme.border }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: theme.dp(50)
            Layout.maximumHeight: theme.dp(50)
            color: theme.field
            radius: theme.dp(10)
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height / 2; color: parent.color }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: theme.dp(14); anchors.rightMargin: theme.dp(14)
                spacing: theme.dp(18)
                Repeater {
                    model: [{key: "video", label: qsTr("Video"), icon: "video"}, {key: "audio", label: qsTr("Audio"), icon: "audio"}, {key: "subtitles", label: qsTr("Subtitles"), icon: "subtitles"}]
                    RedesignButton {
                        required property var modelData
                        objectName: "trackTab_" + modelData.key
                        Layout.fillWidth: true; Layout.fillHeight: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        text: modelData.label; caption: root.width > theme.dp(360) ? text : ""; iconName: modelData.icon
                        iconSize: theme.dp(20)
                        foreground: root.page === modelData.key ? root.theme.foreground : Qt.darker(root.theme.foreground, 1.3)
                        onClicked: root.page = modelData.key
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: root.theme.dp(2)
                            color: root.theme.accent
                            visible: root.page === parent.modelData.key
                        }
                    }
                }
            }
        }
        C.ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 0
                RedesignTracks {
                    objectName: "embeddedTrackChoices"
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    heading: qsTr("Embedded Tracks")
                    trackModel: root.currentTracks
                    allowDisable: true
                    onSelectionRequested: (index, selected) => root.selectionRequested(trackModel, index, selected)
                    onDisableRequested: root.disableRequested(trackModel)
                }
                Rectangle {
                    visible: root.page === "audio" || root.page === "subtitles"
                    Layout.fillWidth: true; Layout.preferredHeight: theme.dp(1)
                    Layout.topMargin: theme.dp(12)
                    color: theme.border
                }
                RedesignTracks {
                    Layout.fillWidth: true
                    visible: root.page === "audio"
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    heading: qsTr("Output Device"); trackModel: root.audioDevices
                    onSelectionRequested: (index, selected) => root.selectionRequested(trackModel, index, selected)
                }
                RedesignButton {
                    visible: root.page === "subtitles"
                    Layout.fillWidth: true
                    Layout.leftMargin: theme.dp(20); Layout.rightMargin: theme.dp(20)
                    Layout.topMargin: theme.dp(16)
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    leftAligned: true
                    iconName: "add"; caption: qsTr("Add subtitle file"); text: caption
                    onClicked: root.addSubtitleFileRequested()
                }
            }
        }
        RedesignButton {
            objectName: "trackPreferencesButton"
            Layout.fillWidth: true
            Layout.preferredHeight: theme.dp(32); Layout.maximumHeight: theme.dp(32)
            Layout.margins: theme.dp(20)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            caption: qsTr("Show Preferences"); text: caption
            background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.field; radius: root.theme.dp(4); border.width: parent.visualFocus ? 1 : 0; border.color: root.theme.accent }
            onClicked: { root.close(); root.preferencesRequested(root.page) }
        }
    }
}
