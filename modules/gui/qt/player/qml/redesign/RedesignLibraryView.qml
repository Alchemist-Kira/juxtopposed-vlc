// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

Item {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var mediaModel
    property int itemCount: mediaView.count
    property int category: 1
    property string heading: qsTr("Videos")
    property string searchText: ""
    property bool grid: false
    property bool descending: false
    property bool canGoBack: false
    property bool canGoForward: false
    property bool canEnqueue: true
    property bool showingFolders: false
    property string emptyText: qsTr("Add a folder to your library to see your media here.")
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal categoryRequested(int category)
    signal activated(int index)
    signal enqueueRequested(int index)
    signal addRequested()
    signal fullLibraryRequested()
    signal backRequested()
    signal forwardRequested()
    signal newPlaylistRequested()

    Rectangle {
        id: rail
        anchors.top: parent.top; anchors.bottom: parent.bottom; width: theme.dp(50)
        color: theme.background
        Column {
            anchors.top: parent.top; anchors.topMargin: theme.dp(6)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: theme.dp(10)
            Repeater {
                model: [qsTr("Home"), qsTr("Videos"), qsTr("Music"), qsTr("Network streams"), qsTr("Playlists"), qsTr("Recent files"), qsTr("Add media")]
                RedesignButton {
                    required property int index
                    required property string modelData
                    objectName: "libraryCategory" + index
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    iconName: ["home", "videos", "music", "network", "queue", "history", "add"][index]
                    text: modelData; selected: root.category === index
                    onClicked: index === 6 ? root.addRequested() : root.categoryRequested(index)
                }
            }
        }
    }
    ColumnLayout {
        anchors { top: parent.top; bottom: parent.bottom; left: rail.right; right: parent.right; margins: theme.dp(20); topMargin: theme.dp(12) }
        spacing: theme.dp(10)
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            RedesignButton {
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "back"; text: qsTr("Back"); enabled: root.canGoBack
                onClicked: root.backRequested()
            }
            RedesignButton {
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "forward"; text: qsTr("Forward"); enabled: root.canGoForward
                onClicked: root.forwardRequested()
            }
            Text {
                Layout.fillWidth: true
                text: root.heading; elide: Text.ElideRight
                color: theme.foreground; font.pixelSize: theme.dp(16)
            }
            RedesignButton {
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "add"; text: qsTr("Add media")
                onClicked: root.addRequested()
            }
            RedesignButton {
                objectName: "expandLibraryButton"
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "expand"; text: qsTr("Open full library")
                onClicked: root.fullLibraryRequested()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: qsTr("%n item(s)", "", root.itemCount)
                color: theme.foreground; font.pixelSize: theme.dp(14)
            }
            RedesignButton {
                objectName: "librarySortButton"
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "sort"; text: root.descending ? qsTr("Sort ascending") : qsTr("Sort descending")
                selected: root.descending
                onClicked: root.descending = !root.descending
            }
            RedesignButton {
                objectName: "libraryViewButton"
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: root.grid ? "queue" : "grid"; text: root.grid ? qsTr("List view") : qsTr("Grid view")
                onClicked: root.grid = !root.grid
            }
            RedesignButton {
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "search"; text: qsTr("Search library"); selected: searchField.visible
                onClicked: { searchField.visible = !searchField.visible; if (searchField.visible) searchField.forceActiveFocus(); else root.searchText = "" }
            }
        }
        C.TextField {
            id: searchField
            objectName: "librarySearchField"
            Layout.fillWidth: true
            visible: false
            placeholderText: qsTr("Search library")
            text: root.searchText
            onTextEdited: root.searchText = text
            color: theme.bright
            font.pixelSize: theme.dp(14)
            background: Rectangle { color: theme.field; radius: theme.dp(4); border.color: searchField.activeFocus ? theme.accent : theme.border }
        }
        Rectangle { Layout.fillWidth: true; height: theme.dp(1); color: theme.border }
        RedesignButton {
            visible: root.category === 4 && !root.canGoBack
            Layout.fillWidth: true
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            iconName: "add"; caption: qsTr("Create playlist"); text: caption
            onClicked: root.newPlaylistRequested()
        }
        GridView {
            id: mediaView
            objectName: "libraryMediaView"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root.mediaModel
            visible: root.itemCount > 0
            cellWidth: root.grid ? width / Math.max(1, Math.floor(width / theme.dp(130))) : width
            cellHeight: root.grid ? theme.dp(142) : theme.dp(42)
            keyNavigationEnabled: true
            currentIndex: -1
            C.ScrollBar.vertical: C.ScrollBar { policy: C.ScrollBar.AsNeeded }
            delegate: Item {
                id: delegate
                required property int index
                required property var model
                width: mediaView.cellWidth
                height: mediaView.cellHeight
                readonly property string itemTitle: model.title || model.name || model.fileName || (model.url ? decodeURIComponent(model.url.toString().replace(/\/$/, "").split("/").pop()) : "")
                readonly property string itemArtwork: model.thumbnail || model.small_cover || model.cover || ""
                RedesignButton {
                    id: mediaButton
                    objectName: "libraryMediaItem" + delegate.index
                    anchors.fill: parent
                    anchors.margins: theme.dp(2)
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    text: delegate.itemTitle
                    selected: mediaView.currentIndex === delegate.index
                    onClicked: { mediaView.currentIndex = delegate.index; root.activated(delegate.index) }
                    contentItem: Item {
                        Rectangle {
                            id: thumbnail
                            x: root.grid ? theme.dp(4) : 0
                            y: root.grid ? theme.dp(4) : (parent.height - height) / 2
                            width: root.grid ? parent.width - theme.dp(8) : theme.dp(32)
                            height: root.grid ? theme.dp(90) : theme.dp(32)
                            radius: theme.dp(2); color: theme.field
                            RedesignIcon { anchors.centerIn: parent; width: theme.dp(24); height: width; name: model.fileIsDir || root.showingFolders ? "folder" : model.iconName || (root.category === 4 ? "queue" : root.category === 2 ? "music" : "video"); color: theme.foreground }
                            Image { anchors.fill: parent; source: delegate.itemArtwork; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                        }
                        Text {
                            x: root.grid ? theme.dp(4) : thumbnail.width + theme.dp(10)
                            y: root.grid ? thumbnail.y + thumbnail.height + theme.dp(6) : (parent.height - height) / 2
                            width: root.grid ? parent.width - theme.dp(8) : Math.max(0, parent.width - x - theme.dp(26))
                            text: delegate.itemTitle; elide: Text.ElideRight
                            color: mediaButton.hovered || mediaButton.visualFocus ? theme.bright : theme.foreground
                            font.pixelSize: theme.dp(14)
                        }
                    }
                    DragHandler {
                        id: dragHandler
                        target: null
                        enabled: root.canEnqueue
                    }
                    Drag.active: false
                    Drag.supportedActions: Qt.CopyAction
                    Drag.keys: ["vlc-redesign-library"]
                    Drag.hotSpot: Qt.point(width / 2, height / 2)
                    property int mediaIndex: delegate.index
                    property var libraryView: root
                    // The queue accepts the model index and resolves it through MediaLib.
                    Connections {
                        target: dragHandler
                        function onActiveChanged() {
                            if (dragHandler.active) mediaButton.Drag.active = true
                            else { mediaButton.Drag.drop(); mediaButton.Drag.active = false }
                        }
                    }
                }
                RedesignButton {
                    visible: root.canEnqueue && !root.grid && (mediaButton.hovered || hovered || mediaButton.visualFocus)
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    implicitWidth: theme.dp(28)
                    iconName: "add"; text: qsTr("Add to queue")
                    onClicked: root.enqueueRequested(delegate.index)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.itemCount === 0
            text: root.searchText.length > 0 ? qsTr("No media matches your search.") : root.emptyText
            wrapMode: Text.WordWrap; color: theme.foreground; font.pixelSize: theme.dp(14)
            verticalAlignment: Text.AlignTop
        }
    }
}
