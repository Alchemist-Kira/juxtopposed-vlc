// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

Item {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var queueModel
    property int itemCount: 0
    property bool random: false
    property bool repeating: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal closeRequested()
    signal addRequested()
    signal saveRequested()
    signal clearRequested()
    signal shuffleRequested()
    signal repeatRequested()
    signal playRequested(int index)
    signal removeRequested(int index)
    signal moveRequested(int from, int to)
    signal libraryDropRequested(var source)

    ColumnLayout {
        anchors.fill: parent; anchors.margins: theme.dp(16)
        spacing: theme.dp(10)
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: qsTr("Queue"); color: theme.bright; font.pixelSize: theme.dp(16) }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "add"; text: qsTr("Add files to queue"); onClicked: root.addRequested() }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "close"; text: qsTr("Close queue"); onClicked: root.closeRequested() }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: qsTr("%n item(s)", "", root.itemCount); color: theme.foreground; font.pixelSize: theme.dp(14) }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "shuffle"; text: qsTr("Shuffle"); selected: root.random; onClicked: root.shuffleRequested() }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "repeat"; text: qsTr("Repeat"); selected: root.repeating; onClicked: root.repeatRequested() }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; iconName: "more"; text: qsTr("Queue actions"); onClicked: queueMenu.popup() }
            C.Menu {
                id: queueMenu
                C.MenuItem { text: qsTr("Save queue to file"); enabled: root.itemCount > 0; onTriggered: root.saveRequested() }
                C.MenuItem { text: qsTr("Clear queue"); enabled: root.itemCount > 0; onTriggered: root.clearRequested() }
            }
        }
        Rectangle { Layout.fillWidth: true; height: theme.dp(1); color: theme.border }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            model: root.queueModel
            clip: true
            C.ScrollBar.vertical: C.ScrollBar {}
            delegate: RowLayout {
                id: row
                required property int index
                required property string title
                required property bool isCurrent
                width: list.width; height: theme.dp(44)
                spacing: theme.dp(2)
                RedesignButton {
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    text: row.title; selected: row.isCurrent
                    contentItem: Text {
                        text: row.title; elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: theme.dp(14)
                        color: row.isCurrent ? theme.accent : theme.foreground
                    }
                    onClicked: root.playRequested(row.index)
                }
                RedesignButton {
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    implicitWidth: theme.dp(26)
                    iconName: "back"; text: qsTr("Move earlier"); enabled: row.index > 0
                    onClicked: root.moveRequested(row.index, row.index - 1)
                }
                RedesignButton {
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    implicitWidth: theme.dp(26)
                    iconName: "close"; text: qsTr("Remove from queue")
                    onClicked: root.removeRequested(row.index)
                }
            }
            Text {
                anchors.fill: parent
                anchors.topMargin: theme.dp(20)
                visible: root.itemCount === 0
                text: qsTr("Drop files here, or add media from your library.")
                wrapMode: Text.WordWrap; color: theme.foreground; font.pixelSize: theme.dp(14)
            }
        }
    }
    DropArea {
        anchors.fill: parent
        keys: ["vlc-redesign-library"]
        onDropped: drop => {
            if (drop.source && drop.source["libraryView"]) {
                root.libraryDropRequested(drop.source)
                drop.acceptProposedAction()
            }
        }
    }
}
