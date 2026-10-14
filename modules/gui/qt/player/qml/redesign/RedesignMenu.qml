// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

C.Popup {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal actionRequested(string action)
    width: theme.dp(290)
    padding: theme.dp(6)
    focus: true
    background: Rectangle { color: theme.background; radius: theme.dp(6); border.color: theme.border }
    contentItem: Column {
        Repeater {
            model: [
                {action: "file", icon: "video", label: qsTr("Open file"), shortcut: "Ctrl+O"},
                {action: "subtitles", icon: "subtitles", label: qsTr("Open subtitle file"), shortcut: ""},
                {action: "directory", icon: "folder", label: qsTr("Open directory"), shortcut: "Ctrl+F"},
                {action: "disc", icon: "video", label: qsTr("Open disc"), shortcut: "Ctrl+D"},
                {action: "network", icon: "network", label: qsTr("Open network stream"), shortcut: "Ctrl+N"},
                {action: "capture", icon: "video", label: qsTr("Open capture device"), shortcut: "Ctrl+C"},
                {action: "convert", icon: "repeat", label: qsTr("Convert"), shortcut: "Ctrl+R"},
                {action: "stream", icon: "network", label: qsTr("Stream to another device"), shortcut: "Ctrl+S"},
                {action: "library", icon: "sidebar", label: qsTr("Full media library"), shortcut: ""},
                {action: "customize", icon: "settings", label: qsTr("Customize player"), shortcut: ""},
                {action: "settings", icon: "settings", label: qsTr("Settings"), shortcut: "Ctrl+P"},
                {action: "advanced", icon: "more", label: qsTr("All VLC actions"), shortcut: ""},
                {action: "about", icon: "cone", label: qsTr("About VLC"), shortcut: ""}
            ]
            RedesignButton {
                required property var modelData
                width: root.availableWidth
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                text: modelData.label
                contentItem: RowLayout {
                    spacing: root.theme.dp(10)
                    RedesignIcon { width: root.theme.dp(20); height: width; name: modelData.icon; color: root.theme.accent }
                    Text { Layout.fillWidth: true; text: modelData.label; color: root.theme.bright; font.pixelSize: root.theme.dp(13) }
                    Text { text: modelData.shortcut; color: root.theme.foreground; font.pixelSize: root.theme.dp(11) }
                }
                onClicked: { root.close(); root.actionRequested(modelData.action) }
            }
        }
    }
}
