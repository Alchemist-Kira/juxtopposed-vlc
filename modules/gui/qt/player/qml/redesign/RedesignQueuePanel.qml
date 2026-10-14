// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import VLC.MainInterface
import VLC.Player
import VLC.Playlist

Item {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property int tab: 0
    property Component queueContent
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; height: theme.dp(50); color: theme.field
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: theme.dp(12); anchors.rightMargin: theme.dp(12)
                Repeater {
                    model: [qsTr("Queue"), qsTr("Bookmarks"), qsTr("Chapters")]
                    RedesignButton {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        caption: modelData; text: modelData; selected: root.tab === index
                        enabled: index !== 1 || MainCtx.mediaLibraryAvailable
                        onClicked: root.tab = index
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: theme.dp(2); color: theme.accent; visible: root.tab === index }
                    }
                }
            }
        }
        Loader { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.tab === 0; active: visible; sourceComponent: root.queueContent }
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.tab === 1; active: visible && MainCtx.mediaLibraryAvailable
            source: active ? "qrc:///qt/qml/VLC/Player/RedesignBookmarks.qml" : ""
            onLoaded: { item.scaleFactor = Qt.binding(() => root.scaleFactor); item.lightTheme = Qt.binding(() => root.lightTheme) }
        }
        ListView {
            id: chapters
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.margins: theme.dp(16)
            visible: root.tab === 2
            clip: true
            model: Player.chapters
            C.ScrollBar.vertical: C.ScrollBar {}
            delegate: Item {
                id: chapter
                required property int index
                required property string display
                required property bool checked
                required property var time
                width: chapters.width; height: theme.dp(42)
                RedesignButton {
                    anchors.fill: parent
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    text: chapter.display; selected: chapter.checked
                    contentItem: RowLayout {
                        Text { Layout.fillWidth: true; text: chapter.display; elide: Text.ElideRight; color: chapter.checked ? theme.accent : theme.foreground; font.pixelSize: theme.dp(14) }
                        Text { text: chapter.time.formatHMS(); color: theme.foreground; font.pixelSize: theme.dp(12) }
                    }
                    onClicked: Player.chapters.setData(Player.chapters.index(chapter.index, 0), true, Qt.CheckStateRole)
                }
            }
            Text { anchors.fill: parent; visible: chapters.count === 0; text: qsTr("This media has no chapters."); color: theme.foreground; font.pixelSize: theme.dp(14) }
        }
    }
}
