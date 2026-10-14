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
    readonly property int libraryMediaCount: mediaView.count
    property int itemCount: libraryMediaCount
    property bool homeSectionsVisible: category === 0
    property var homeSections: []
    property int category: 1
    property string heading: qsTr("Videos")
    property string searchText: ""
    property bool grid: false
    property bool descending: false
    property bool canGoBack: false
    property bool canGoForward: false
    property bool canEnqueue: true
    property string defaultItemIcon: category === 4 ? "queue" : category === 2 ? "music" : "video"
    property bool showingFolders: false
    property bool showAddRow: category > 0 && category < 5
    property string addLabel: category === 4 ? qsTr("Create playlist") : category === 3 ? qsTr("Add Network Stream") : qsTr("Add")
    property string emptyText: qsTr("Add a folder to your library to see your media here.")
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal homeActivated(string section, int index)
    signal homeEnqueueRequested(string section, int index)
    signal homeSectionRequested(string section)
    signal categoryRequested(int category)
    signal activated(int index)
    signal enqueueRequested(int index)
    signal addRequested()
    signal fullLibraryRequested()
    signal backRequested()
    signal forwardRequested()
    signal newPlaylistRequested()
    signal preferencesRequested()

    function nameFromUrl(url) {
        const value = url.toString()
        const name = value.replace(/\\/g, "/").replace(/\/+$/, "").split("/").pop()
        if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(value)) return name
        try { return decodeURIComponent(name) } catch (error) { return name }
    }
    function addMedia() {
        if (category === 4) newPlaylistRequested()
        else addRequested()
    }
    RedesignActionMenu {
        id: moreMenu
        objectName: "libraryMoreMenu"
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        entries: [
            { action: "add", label: root.addLabel, icon: "add" },
            { action: "settings", label: qsTr("Library settings"), icon: "settings" }
        ]
        onActionRequested: action => action === "add" ? root.addMedia() : root.preferencesRequested()
    }
    RedesignActionMenu {
        id: viewMenu
        objectName: "libraryViewMenu"
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        entries: [
            { action: "grid", label: qsTr("Grid View"), icon: "grid", checked: root.grid },
            { action: "list", label: qsTr("List View"), icon: "list-view", checked: !root.grid }
        ]
        onActionRequested: action => root.grid = action === "grid"
    }

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
                    iconName: [root.category === 0 ? "home-active" : "home", "videos", "music", "network", "playlist", "history", "add"][index]
                    text: modelData; selected: root.category === index
                    onClicked: index === 6 ? root.addRequested() : root.categoryRequested(index)
                    background: Rectangle {
                        radius: root.theme.dp(6)
                        color: parent.down ? root.theme.selected : parent.hovered ? root.theme.hover : "transparent"
                        border.width: parent.visualFocus ? root.theme.dp(2) : 0
                        border.color: root.theme.accent
                    }
                }
            }
        }
    }
    ColumnLayout {
        anchors { top: parent.top; bottom: parent.bottom; left: rail.right; right: parent.right; margins: theme.dp(20); topMargin: theme.dp(12) }
        spacing: theme.dp(10)
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: -theme.dp(6)
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
                text: root.heading; elide: Text.ElideLeft
                color: theme.foreground; font.pixelSize: theme.dp(16)
            }
            RedesignButton {
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                id: moreButton
                objectName: "libraryMoreButton"
                iconName: "more"; text: qsTr("More library actions")
                onClicked: moreMenu.popup(moreButton, 0, height)
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
                text: qsTr("%n item", "%n items", root.itemCount)
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
                id: viewButton
                objectName: "libraryViewButton"
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: root.grid ? "grid" : "list-view"; text: qsTr("View options")
                onClicked: viewMenu.popup(viewButton, 0, height)
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
            objectName: "libraryAddRow"
            visible: root.showAddRow
            Layout.topMargin: theme.dp(5)
            Layout.fillWidth: true
            implicitHeight: theme.dp(42)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            text: root.addLabel
            onClicked: root.addMedia()
            contentItem: Row {
                spacing: theme.dp(10)
                Item {
                    width: theme.dp(32); height: theme.dp(42)
                    RedesignIcon { anchors.centerIn: parent; width: theme.dp(24); height: width; name: "add"; color: theme.foreground }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.addLabel; color: theme.foreground; font.pixelSize: theme.dp(14) }
            }
        }
        RedesignHomeView {
            objectName: "libraryHomeView"
            visible: root.homeSectionsVisible
            Layout.topMargin: theme.dp(9)
            Layout.fillWidth: true; Layout.fillHeight: true
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            sections: root.homeSectionsVisible ? root.homeSections : []
            onActivated: (section, index) => root.homeActivated(section, index)
            onEnqueueRequested: (section, index) => root.homeEnqueueRequested(section, index)
            onSectionRequested: section => root.homeSectionRequested(section)
        }
        GridView {
            id: mediaView
            objectName: "libraryMediaView"
            Layout.topMargin: root.showAddRow ? -theme.dp(10) : theme.dp(5)
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root.mediaModel
            visible: !root.homeSectionsVisible && root.itemCount > 0
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
                readonly property string itemTitle: model.title || model.name || model.fileName || (model.url ? root.nameFromUrl(model.url) : "")
                readonly property string itemArtwork: model.thumbnail || model.small_cover || model.cover || ""
                RedesignButton {
                    id: mediaButton
                    objectName: "libraryMediaItem" + delegate.index
                    anchors.fill: parent
                    anchors.margins: 0
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
                            radius: theme.dp(2); color: model.fileIsDir || root.showingFolders || model.iconName ? "transparent" : theme.field
                            RedesignIcon { anchors.centerIn: parent; width: theme.dp(24); height: width; name: model.fileIsDir || root.showingFolders ? "folder" : model.iconName || root.defaultItemIcon; color: theme.foreground }
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
                    RedesignLibraryDrag {
                        handler: dragHandler
                        libraryView: root
                        mediaIndex: delegate.index
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
            visible: !root.homeSectionsVisible && root.itemCount === 0
            text: root.searchText.length > 0 ? qsTr("No media matches your search.") : root.emptyText
            wrapMode: Text.WordWrap; color: theme.foreground; font.pixelSize: theme.dp(14)
            verticalAlignment: Text.AlignTop
        }
    }
}
