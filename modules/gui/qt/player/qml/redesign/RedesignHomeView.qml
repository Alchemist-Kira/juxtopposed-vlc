// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls.Basic as C

Flickable {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var sections: []
    signal activated(string section, int index)
    signal enqueueRequested(string section, int index)
    signal sectionRequested(string section)
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    contentWidth: width
    contentHeight: groups.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    C.ScrollBar.vertical: C.ScrollBar { policy: C.ScrollBar.AsNeeded }
    Column {
        id: groups
        width: root.width
        spacing: root.theme.dp(24)
        Repeater {
            model: root.sections
            Column {
                id: section
                required property var modelData
                width: groups.width
                spacing: root.theme.dp(10)
                RedesignButton {
                    objectName: "homeSection_" + section.modelData.key
                    width: parent.width; height: root.theme.dp(32)
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    text: section.modelData.title
                    onClicked: root.sectionRequested(section.modelData.key)
                    contentItem: Item {
                        Text {
                            anchors.left: parent.left; anchors.right: arrow.left; anchors.verticalCenter: parent.verticalCenter
                            text: section.modelData.title; elide: Text.ElideRight
                            color: root.theme.foreground; font.pixelSize: root.theme.dp(16)
                        }
                        RedesignIcon { id: arrow; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: root.theme.dp(24); height: width; name: "chevron-right"; color: root.theme.foreground }
                    }
                }
                Column {
                    width: parent.width
                    Repeater {
                        model: section.modelData.model
                        delegate: Item {
                            id: entry
                            required property int index
                            required property var model
                            width: section.width
                            height: visible ? root.theme.dp(42) : 0
                            visible: index < 3
                            readonly property string title: model.title || model.name || ""
                            readonly property string displayTitle: title + (section.modelData.key === "listening" && model.main_artist ? " - " + model.main_artist : "")
                            readonly property string artwork: model.thumbnail || model.small_cover || model.cover || ""
                            RedesignButton {
                                id: button
                                objectName: "homeItem_" + section.modelData.key + "_" + entry.index
                                anchors.fill: parent
                                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                                text: entry.displayTitle
                                onClicked: root.activated(section.modelData.key, entry.index)
                                property int mediaIndex: entry.index
                                property QtObject libraryView: QtObject {
                                    function enqueueRequested(index) { root.enqueueRequested(section.modelData.key, index) }
                                }
                                DragHandler { id: dragHandler; target: null }
                                RedesignLibraryDrag {
                                    handler: dragHandler
                                    libraryView: button.libraryView
                                    mediaIndex: entry.index
                                }
                                contentItem: Item {
                                    Item {
                                        id: cover
                                        width: root.theme.dp(32); height: width
                                        anchors.verticalCenter: parent.verticalCenter
                                        RedesignIcon { anchors.centerIn: parent; width: root.theme.dp(24); height: width; name: section.modelData.icon; color: root.theme.foreground }
                                        Image { anchors.fill: parent; source: entry.artwork; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                                    }
                                    Text {
                                        x: cover.width + root.theme.dp(10)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(0, parent.width - x - root.theme.dp(28))
                                        text: entry.displayTitle; elide: Text.ElideRight
                                        color: button.hovered || button.visualFocus ? root.theme.bright : root.theme.foreground
                                        font.pixelSize: root.theme.dp(14)
                                    }
                                }
                            }
                            RedesignButton {
                                visible: button.hovered || hovered || button.visualFocus
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: root.theme.dp(28)
                                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                                iconName: "add"; text: qsTr("Add to queue")
                                onClicked: root.enqueueRequested(section.modelData.key, entry.index)
                            }
                        }
                    }
                    Text {
                        visible: section.modelData.model.count === 0
                        width: parent.width; height: root.theme.dp(42)
                        verticalAlignment: Text.AlignVCenter
                        text: section.modelData.emptyText
                        wrapMode: Text.WordWrap; color: root.theme.foreground; font.pixelSize: root.theme.dp(14)
                    }
                }
            }
        }
    }
}
