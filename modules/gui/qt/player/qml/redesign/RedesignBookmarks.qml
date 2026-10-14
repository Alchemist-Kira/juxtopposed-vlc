// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import VLC.Player
import VLC.MediaLibrary

Item {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    MLBookmarkModel { id: bookmarks; ml: MediaLib; player: Player }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: theme.dp(16)
        spacing: theme.dp(12)
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: qsTr("%n bookmark(s)", "", list.count); color: theme.foreground; font.pixelSize: theme.dp(14) }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "add"; text: qsTr("Bookmark current time"); enabled: Player.isStarted; onClicked: bookmarks.add() }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            model: bookmarks
            clip: true
            C.ScrollBar.vertical: C.ScrollBar {}
            delegate: RowLayout {
                id: row
                required property int index
                required property string name
                required property string time
                width: list.width; height: theme.dp(42)
                RedesignButton {
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    caption: row.name; text: caption
                    onClicked: bookmarks.select(bookmarks.index(row.index, 0))
                }
                Text { text: row.time; color: theme.foreground; font.pixelSize: theme.dp(12) }
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; implicitWidth: theme.dp(28); iconName: "close"; text: qsTr("Remove bookmark"); onClicked: bookmarks.remove([bookmarks.index(row.index, 0)]) }
            }
            Text {
                anchors.fill: parent; anchors.topMargin: theme.dp(16)
                visible: list.count === 0
                text: qsTr("Save a moment with the + button.")
                color: theme.foreground; font.pixelSize: theme.dp(14); wrapMode: Text.WordWrap
            }
        }
    }
}
