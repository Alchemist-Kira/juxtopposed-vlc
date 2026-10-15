// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import VLC.MainInterface
import VLC.Player
import VLC.Playlist

Item {
    id: root
    Component.onCompleted: console.debug("Play queue panel ready")
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property int tab: 0
    property bool floating: false
    property Component queueContent
    signal closeRequested()
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; height: theme.dp(root.floating ? 60 : 50); color: root.floating ? theme.panel : theme.field
            radius: theme.dp(root.floating ? 14 : 10)
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: theme.dp(14); color: parent.color }
            Text {
                anchors.centerIn: parent; visible: root.floating
                text: [qsTr("Queue"), qsTr("Bookmarks"), qsTr("Chapters")][root.tab]
                color: theme.foreground; font.pixelSize: theme.dp(16)
            }
            RedesignButton {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                visible: root.floating
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "more"; text: qsTr("Queue views")
                enabled: root.floating || root.tab === 0
                onClicked: if (root.floating) viewsMenu.popup(); else if (queueBody.item) queueBody.item.openActions()
                RedesignActionMenu {
                    id: viewsMenu
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    checkedAction: String(root.tab)
                    onAboutToShow: entries = [
                        { action: "0", label: qsTr("Queue"), icon: "queue" },
                        { action: "1", label: qsTr("Bookmarks"), icon: "bookmarks", enabled: MainCtx.mediaLibraryAvailable },
                        { action: "2", label: qsTr("Chapters"), icon: "chapters" },
                        { action: "save", label: qsTr("Save queue to file"), enabled: !!queueBody.item && queueBody.item.itemCount > 0 },
                        { action: "clear", label: qsTr("Clear queue"), enabled: !!queueBody.item && queueBody.item.itemCount > 0 },
                        { action: "close", label: qsTr("Close queue") }
                    ]
                    onActionRequested: action => {
                        if (action === "0" || action === "1" || action === "2") root.tab = Number(action)
                        else if (action === "close") root.closeRequested()
                        else if (queueBody.item) queueBody.item.runAction(action)
                    }
                }
            }
            RowLayout {
                visible: !root.floating
                anchors.fill: parent; anchors.leftMargin: theme.dp(14); anchors.rightMargin: theme.dp(14)
                Repeater {
                    model: [qsTr("Queue"), qsTr("Bookmarks"), qsTr("Chapters")]
                    RedesignButton {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        caption: root.width > theme.dp(360) ? modelData : ""; text: modelData; selected: root.tab === index
                        iconName: ["queue", "bookmarks", "chapters"][index]
                        iconSize: theme.dp(20)
                        captionFontSize: 12
                        selectedForeground: theme.foreground
                        foreground: root.tab === index ? theme.foreground : Qt.darker(theme.foreground, 1.5)
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: theme.dp(6) }
                        enabled: index !== 1 || MainCtx.mediaLibraryAvailable
                        onClicked: root.tab = index
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: theme.dp(2); color: theme.accent; visible: root.tab === index }
                    }
                }
            }
        }
        Loader { id: queueBody; Layout.fillWidth: true; Layout.fillHeight: true; visible: root.tab === 0; active: visible; sourceComponent: root.queueContent }
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
