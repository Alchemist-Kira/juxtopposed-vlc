// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls.Basic as C
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Player
import VLC.Dialogs

RedesignLibraryView {
    id: root
    readonly property var emptyParentId: MediaLib.deserializeMlItemIdFromString("")
    property var selectedPlaylist
    property var selectedCollection
    property string currentFolder: ""
    property string musicSection: ""
    property string selectedName: ""
    property var backStack: []
    property var forwardStack: []
    readonly property var activeModel: currentFolder ? folderLoader.item : selectedPlaylist ? playlistMedia : selectedCollection ? collectionTracks : category === 4 ? playlists : category === 2 ? (musicSection === "" ? musicCategories : musicSection === "Albums" ? albums : musicSection === "Artists" ? artists : musicSection === "Genres" ? genres : music) : category === 3 ? streams : category === 0 || category === 5 ? recent : libraryFolders
    mediaModel: activeModel
    heading: [qsTr("Home"), qsTr("Videos"), qsTr("Music"), qsTr("Network streams"), qsTr("Playlists"), qsTr("Recent files")][category] + (musicSection ? " › " + qsTr(musicSection) : "") + (selectedName ? " › " + selectedName : "")
    canGoBack: backStack.length > 0
    canGoForward: forwardStack.length > 0
    showingFolders: category === 1 && !currentFolder
    canEnqueue: !(category === 2 && musicSection === "")
    emptyText: category === 4 ? qsTr("Create a playlist to collect your favorite media.") : category === 3 ? qsTr("Open a network stream to add it here.") : qsTr("Add a folder to your library to see your media here.")

    function snapshot() { return { category: category, playlist: selectedPlaylist, collection: selectedCollection, folder: currentFolder, musicSection: musicSection, name: selectedName, search: searchText } }
    function remember() { backStack = [...backStack, snapshot()]; forwardStack = [] }
    function restore(state) { category = state.category; selectedPlaylist = state.playlist; selectedCollection = state.collection; currentFolder = state.folder; musicSection = state.musicSection; selectedName = state.name; searchText = state.search }
    function folderName(url) { return decodeURIComponent(url.toString().replace(/\/$/, "").split("/").pop()) }
    function openFolder(url) { remember(); currentFolder = url.toString(); selectedName = folderName(url); searchText = "" }
    onCategoryRequested: newCategory => { remember(); selectedPlaylist = undefined; selectedCollection = undefined; currentFolder = ""; musicSection = ""; selectedName = ""; searchText = ""; category = newCategory }
    onBackRequested: { const stack = backStack.slice(); const state = stack.pop(); forwardStack = [...forwardStack, snapshot()]; backStack = stack; restore(state) }
    onForwardRequested: { const stack = forwardStack.slice(); const state = stack.pop(); backStack = [...backStack, snapshot()]; forwardStack = stack; restore(state) }
    onActivated: index => {
        if (currentFolder) {
            const url = folderLoader.item.get(index, "fileUrl")
            if (folderLoader.item.get(index, "fileIsDir")) openFolder(url)
            else MediaLib.addAndPlay(url)
        } else if (category === 1) {
            openFolder(libraryFolders.data(libraryFolders.index(index, 0), MLFolderModel.MRL))
        } else if (category === 2 && musicSection === "") {
            remember(); musicSection = ["Songs", "Albums", "Artists", "Genres"][index]
        } else {
            const item = activeModel.getDataAt(index)
            if (category === 4 && !selectedPlaylist) { remember(); selectedPlaylist = item.id; selectedName = item.name; searchText = "" }
            else if (category === 2 && musicSection !== "Songs" && !selectedCollection) { remember(); selectedCollection = item.id; selectedName = item.title || item.name; searchText = "" }
            else MediaLib.addAndPlay(item.id)
        }
    }
    onEnqueueRequested: index => {
        if (currentFolder) MediaLib.addToPlaylist(folderLoader.item.get(index, "fileUrl"))
        else if (category === 1) MediaLib.addToPlaylist(libraryFolders.data(libraryFolders.index(index, 0), MLFolderModel.MRL))
        else MediaLib.addToPlaylist(activeModel.getDataAt(index).id)
    }
    onAddRequested: {
        if (category === 3) networkDialog.open()
        else { const folder = DialogsProvider.selectLibraryFolder(); if (folder.toString().length > 0) libraryFolders.add(folder) }
    }
    onNewPlaylistRequested: { playlistName.text = ""; createPlaylist.open(); playlistName.forceActiveFocus() }

    Loader {
        id: folderLoader
        active: root.currentFolder.length > 0
        sourceComponent: RedesignFolderModel {
            folder: root.currentFolder
            nameFilters: DialogsProvider.mediaNameFilters(root.category === 2)
            sortReversed: root.descending
        }
    }
    ListModel {
        id: musicCategories
        ListElement { title: QT_TR_NOOP("Songs"); iconName: "music" }
        ListElement { title: QT_TR_NOOP("Albums"); iconName: "music" }
        ListElement { title: QT_TR_NOOP("Artists"); iconName: "audio" }
        ListElement { title: QT_TR_NOOP("Genres"); iconName: "queue" }
    }
    MLAudioModel { id: music; ml: MediaLib; searchPattern: root.searchText; sortOrder: root.descending ? Qt.DescendingOrder : Qt.AscendingOrder }
    MLAlbumModel { id: albums; ml: MediaLib; searchPattern: root.searchText; sortOrder: root.descending ? Qt.DescendingOrder : Qt.AscendingOrder }
    MLArtistModel { id: artists; ml: MediaLib; searchPattern: root.searchText; sortOrder: root.descending ? Qt.DescendingOrder : Qt.AscendingOrder }
    MLGenreModel { id: genres; ml: MediaLib; searchPattern: root.searchText; sortOrder: root.descending ? Qt.DescendingOrder : Qt.AscendingOrder }
    MLAudioModel { id: collectionTracks; ml: MediaLib; parentId: root.selectedCollection || root.emptyParentId; searchPattern: root.searchText; sortOrder: root.descending ? Qt.DescendingOrder : Qt.AscendingOrder }
    MLRecentMediaModel { id: recent; ml: MediaLib; searchPattern: root.searchText }
    MLPlaylistListModel { id: playlists; ml: MediaLib; searchPattern: root.searchText; sortOrder: root.descending ? Qt.DescendingOrder : Qt.AscendingOrder }
    MLPlaylistModel { id: playlistMedia; ml: MediaLib; parentId: root.selectedPlaylist || root.emptyParentId; searchPattern: root.searchText }
    MLUrlModel { id: streams; ml: MediaLib; searchPattern: root.searchText }
    MLFolderModel { id: libraryFolders; ctx: MainCtx }
    C.Dialog {
        id: createPlaylist
        parent: root
        anchors.centerIn: parent
        width: Math.min(root.width - root.theme.dp(20), root.theme.dp(320))
        title: qsTr("Create playlist")
        modal: true
        standardButtons: C.Dialog.Ok | C.Dialog.Cancel
        contentItem: C.TextField { id: playlistName; placeholderText: qsTr("Playlist name"); onAccepted: createPlaylist.accept() }
        onAccepted: if (playlistName.text.trim().length > 0) playlists.create(playlistName.text.trim(), [])
    }
    C.Dialog {
        id: networkDialog
        parent: root
        anchors.centerIn: parent
        width: Math.min(root.width - root.theme.dp(20), root.theme.dp(360))
        title: qsTr("Open network stream")
        modal: true
        standardButtons: C.Dialog.Open | C.Dialog.Cancel
        contentItem: C.TextField { id: streamUrl; placeholderText: qsTr("https://…"); onAccepted: networkDialog.accept() }
        onAccepted: if (streamUrl.text.trim().length > 0) streams.addAndPlay(streamUrl.text.trim())
    }
}
