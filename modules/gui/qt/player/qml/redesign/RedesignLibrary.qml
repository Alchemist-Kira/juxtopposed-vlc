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
    property string homeSection: ""
    property string currentFolder: ""
    property var folderTrail: []
    property string musicSection: ""
    property string selectedName: ""
    property var backStack: []
    property var forwardStack: []
    settingsContext: MainCtx
    sortScope: homeSection ? "home/" + homeSection : currentFolder ? "folder/" + (category === 2 ? "audio" : "video")
        : selectedPlaylist ? "playlist-media" : selectedCollection ? "audio-tracks"
        : category === 2 ? "music/" + musicSection : "category/" + category
    sortFields: {
        if (homeSectionsVisible || category === 2 && !musicSection && !currentFolder) return []
        if (currentFolder) return ["title", "insertion", "uri"]
        if (homeSection === "folders" || category === 1) return ["title", "uri"]
        if (homeSection === "playlists" || homeSection === "artists") return ["title"]
        if (homeSection === "watching") return ["played", "insertion", "title", "uri"]
        if (category === 3) return ["insertion", "uri"]
        if (category === 4 && !selectedPlaylist) return ["insertion", "title"]
        if (category === 2 && !selectedCollection && musicSection !== "Songs")
            return musicSection === "Albums" ? ["title", "main_artist"] : ["title"]
        return ["played", "insertion", "title", "main_artist", "album_title", "track_number", "uri", "disc_number"]
    }
    extraSortOptions: ["folders", "playlists", "artists"].includes(homeSection)
        ? [{id: "frequency", field: "frequency", descending: true, label: homeSection === "artists" ? qsTr("Most played first") : qsTr("Most visited first")}]
        : selectedPlaylist ? [{id: "original", field: "", descending: false, label: qsTr("Playlist order")}] : []
    defaultSortChoice: extraSortOptions.length ? extraSortOptions[0].id
        : ["watching", "listening"].includes(homeSection) || category === 3 || category === 5 ? "newest" : "title-asc"
    readonly property string mediaSortField: sortField === "frequency" ? ""
        : sortField === "insertion" && (["watching", "listening"].includes(homeSection) || category === 3 || category === 5) ? ""
        : sortField === "title" && (homeSection === "artists" || category === 2 && !selectedCollection && ["Artists", "Genres"].includes(musicSection)) ? "name" : sortField
    readonly property int mediaSortOrder: descending ? Qt.DescendingOrder : Qt.AscendingOrder
    readonly property var homeModels: ({watching: recentVideo, listening: recentAudio, folders: frequentFolders, playlists: frequentPlaylists, artists: playedArtists})
    readonly property var homeTitles: ({watching: qsTr("Continue Watching"), listening: qsTr("Listen Again"), folders: qsTr("Frequently Visited Folders"), playlists: qsTr("Frequently Visited Playlists"), artists: qsTr("Frequently Listened Artists")})
    homeSectionsVisible: category === 0 && !homeSection
    homeSections: [
        {key: "watching", title: homeTitles.watching, model: recentVideo, icon: "video", emptyText: qsTr("No videos in your history.")},
        {key: "listening", title: homeTitles.listening, model: recentAudio, icon: "music", emptyText: qsTr("No music in your history.")},
        {key: "folders", title: homeTitles.folders, model: frequentFolders, icon: "folder", emptyText: qsTr("Open a library folder to see it here.")},
        {key: "playlists", title: homeTitles.playlists, model: frequentPlaylists, icon: "playlist", emptyText: qsTr("Open a playlist to see it here.")},
        {key: "artists", title: homeTitles.artists, model: playedArtists, icon: "artist", emptyText: qsTr("Play music to see artists here.")}
    ]
    itemCount: homeSectionsVisible ? recentVideo.maximumCount + recentAudio.maximumCount + frequentFolders.count + frequentPlaylists.count + playedArtists.maximumCount : currentFolder ? (folderLoader.item ? folderLoader.item.count : 0) : activeModel && activeModel.count !== undefined ? activeModel.count : libraryMediaCount
    readonly property var activeModel: homeSection ? homeModels[homeSection] : currentFolder ? folderLoader.item : selectedPlaylist ? playlistMedia : selectedCollection ? collectionTracks : category === 4 ? playlists : category === 2 ? (musicSection === "" ? musicCategories : musicSection === "Albums" ? albums : musicSection === "Artists" ? artists : musicSection === "Genres" ? genres : music) : category === 3 ? streams : category === 0 || category === 5 ? recent : folderEntries
    mediaModel: activeModel
    heading: [qsTr("Home"), qsTr("Videos"), qsTr("Music"), qsTr("Network streams"), qsTr("Playlists"), qsTr("Recent files")][category] + (homeSection ? " › " + homeTitles[homeSection] : "") + (musicSection ? " › " + qsTr(musicSection) : "") + (currentFolder ? " › " + folderTrail.map(url => nameFromUrl(url)).join(" › ") : selectedName ? " › " + selectedName : "")
    canGoBack: backStack.length > 0
    canGoForward: forwardStack.length > 0
    defaultItemIcon: homeSection === "artists" ? "artist" : homeSection === "listening" ? "music" : category === 4 ? "playlist" : category === 2 ? "music" : "video"
    showingFolders: category === 1 && !currentFolder || homeSection === "folders"
    showAddRow: category > 0 && category < 5 && !selectedPlaylist && !selectedCollection && (category !== 1 || !currentFolder || (folderLoader.item && folderLoader.item.directoryCount > 0))
    canEnqueue: !(category === 2 && musicSection === "")
    emptyText: homeSection ? homeSections.find(section => section.key === homeSection).emptyText : selectedPlaylist ? qsTr("This playlist is empty.") : category === 4 ? qsTr("Create a playlist to collect your favorite media.") : category === 3 ? qsTr("Open a network stream to add it here.") : qsTr("Add a folder to your library to see your media here.")

    function snapshot() { return { category: category, homeSection: homeSection, playlist: selectedPlaylist, collection: selectedCollection, folder: currentFolder, folderTrail: folderTrail.slice(), musicSection: musicSection, name: selectedName, search: searchText } }
    function remember() { backStack = [...backStack, snapshot()]; forwardStack = [] }
    function restore(state) { category = state.category; homeSection = state.homeSection || ""; selectedPlaylist = state.playlist; selectedCollection = state.collection; currentFolder = state.folder; folderTrail = state.folderTrail || []; musicSection = state.musicSection; selectedName = state.name; searchText = state.search; if (currentFolder) visits.record("folders", currentFolder, nameFromUrl(currentFolder)); else if (selectedPlaylist) visits.record("playlists", selectedPlaylist.toString(), selectedName) }
    function openFolder(url) {
        remember()
        folderTrail = currentFolder ? [...folderTrail, url.toString()] : [url.toString()]
        currentFolder = url.toString()
        category = category === 2 ? 2 : 1
        homeSection = ""
        selectedName = nameFromUrl(url)
        visits.record("folders", currentFolder, selectedName)
        searchText = ""
    }
    function openArtistByName(name) {
        remember()
        category = 2; homeSection = ""; selectedPlaylist = undefined; selectedCollection = undefined
        currentFolder = ""; folderTrail = []; musicSection = "Artists"; selectedName = ""; searchText = name
    }
    onCategoryRequested: newCategory => { remember(); homeSection = ""; selectedPlaylist = undefined; selectedCollection = undefined; currentFolder = ""; folderTrail = []; musicSection = ""; selectedName = ""; searchText = ""; category = newCategory }
    onBackRequested: { const stack = backStack.slice(); const state = stack.pop(); forwardStack = [...forwardStack, snapshot()]; backStack = stack; restore(state) }
    onForwardRequested: { const stack = forwardStack.slice(); const state = stack.pop(); backStack = [...backStack, snapshot()]; forwardStack = stack; restore(state) }
    onActivated: index => {
        if (homeSection) { openHomeItem(homeSection, index); return }
        if (currentFolder) {
            const url = folderLoader.item.get(index, "fileUrl")
            if (folderLoader.item.get(index, "fileIsDir")) openFolder(url)
            else MediaLib.addAndPlay(url)
        } else if (category === 1) {
            openFolder(folderEntries.get(index).fileUrl)
        } else if (category === 2 && musicSection === "") {
            remember(); musicSection = ["Songs", "Albums", "Artists", "Genres"][index]
        } else {
            const item = activeModel.getDataAt(index)
            if (category === 4 && !selectedPlaylist) { remember(); selectedPlaylist = item.id; selectedName = item.name; searchText = ""; visits.record("playlists", item.id.toString(), item.name) }
            else if (category === 2 && musicSection !== "Songs" && !selectedCollection) { remember(); selectedCollection = item.id; selectedName = item.title || item.name; searchText = "" }
            else MediaLib.addAndPlay(item.id)
        }
    }
    onEnqueueRequested: index => {
        if (homeSection) { enqueueHomeItem(homeSection, index); return }
        if (currentFolder) MediaLib.addToPlaylist(folderLoader.item.get(index, "fileUrl"))
        else if (category === 1) MediaLib.addToPlaylist(folderEntries.get(index).fileUrl)
        else MediaLib.addToPlaylist(activeModel.getDataAt(index).id)
    }
    onAddRequested: {
        if (category === 3) networkDialog.open()
        else { const folder = DialogsProvider.selectLibraryFolder(); if (folder.toString().length > 0) libraryFolders.add(folder) }
    }
    onPreferencesRequested: DialogsProvider.prefsPageDialog("library")
    onNewPlaylistRequested: { playlistName.text = ""; createPlaylist.open(); playlistName.forceActiveFocus() }

    function homeItem(section, index) {
        const model = homeModels[section]
        if (section === "folders" || section === "playlists") {
            const item = model.get(index)
            return {key: item.key, name: item.name}
        }
        return model.getDataAt(index)
    }
    function openHomeItem(section, index) {
        const item = homeItem(section, index)
        if (section === "folders") { openFolder(item.key); return }
        if (section === "playlists" || section === "artists") {
            remember()
            homeSection = ""; currentFolder = ""; folderTrail = []; musicSection = ""; searchText = ""
            selectedPlaylist = undefined; selectedCollection = undefined
            if (section === "playlists") {
                category = 4; selectedPlaylist = MediaLib.deserializeMlItemIdFromString(item.key); selectedName = item.name
                visits.record("playlists", item.key, item.name)
            } else {
                category = 2; musicSection = "Artists"; selectedCollection = item.id; selectedName = item.name
            }
        } else MediaLib.addAndPlay(item.id)
    }
    function enqueueHomeItem(section, index) {
        const item = homeItem(section, index)
        MediaLib.addToPlaylist(section === "folders" ? item.key : section === "playlists" ? MediaLib.deserializeMlItemIdFromString(item.key) : item.id)
    }
    onHomeActivated: (section, index) => openHomeItem(section, index)
    onHomeEnqueueRequested: (section, index) => enqueueHomeItem(section, index)
    onHomeSectionRequested: section => { remember(); homeSection = section; searchText = "" }
    function refreshVisits() {
        if (!frequentFolders || !frequentPlaylists || !visits) return
        frequentFolders.clear(); frequentPlaylists.clear()
        for (const kind of ["folders", "playlists"]) {
            const items = visits.ranked(kind, searchText)
            if (homeSection === kind && sortField !== "frequency")
                items.sort((a, b) => compareEntries(a, b))
            for (const item of items)
                (kind === "folders" ? frequentFolders : frequentPlaylists).append({key: item.key, name: item.name, iconName: kind === "folders" ? "folder" : "playlist"})
        }
    }
    function compareEntries(a, b) {
        const av = sortField === "uri" ? a.key : a.name.toLocaleLowerCase()
        const bv = sortField === "uri" ? b.key : b.name.toLocaleLowerCase()
        const order = av < bv ? -1 : av > bv ? 1 : 0
        return order ? (descending ? -order : order) : a.key < b.key ? -1 : a.key > b.key ? 1 : 0
    }
    function refreshFolders() {
        if (!libraryFolders || !folderEntries) return
        const rows = []
        for (let i = 0; i < libraryFolders.rowCount(); ++i) {
            const url = libraryFolders.data(libraryFolders.index(i, 0), MLFolderModel.MRL).toString()
            const name = nameFromUrl(url)
            if (name.toLocaleLowerCase().includes(searchText.toLocaleLowerCase())) rows.push({key: url, name: name})
        }
        rows.sort((a, b) => compareEntries(a, b))
        folderEntries.clear()
        for (const row of rows) folderEntries.append({fileUrl: row.key, fileName: row.name, fileIsDir: true})
    }
    onSearchTextChanged: { refreshVisits(); refreshFolders() }
    onHomeSectionChanged: refreshVisits()
    Connections {
        target: root.sortState
        function onSelectionChanged() { root.refreshVisits(); root.refreshFolders() }
    }
    RedesignLibraryVisits { id: visits; ctx: MainCtx; onEntriesChanged: root.refreshVisits() }
    ListModel { id: frequentFolders }
    ListModel { id: frequentPlaylists }
    MLRecentVideoModel { id: recentVideo; ml: MediaLib; sortCriteria: root.homeSection === "watching" ? root.mediaSortField : ""; sortOrder: root.homeSection === "watching" ? root.mediaSortOrder : Qt.DescendingOrder; limit: root.homeSectionsVisible ? (root.expanded ? 6 : 3) : 0; searchPattern: root.searchText }
    MLRecentAudioModel { id: recentAudio; ml: MediaLib; sortCriteria: root.homeSection === "listening" ? root.mediaSortField : ""; sortOrder: root.homeSection === "listening" ? root.mediaSortOrder : Qt.DescendingOrder; limit: root.homeSectionsVisible ? (root.expanded ? 6 : 3) : 0; searchPattern: root.searchText }
    MLPlayedArtistModel { id: playedArtists; ml: MediaLib; sortCriteria: root.homeSection === "artists" ? root.mediaSortField : ""; sortOrder: root.mediaSortOrder; limit: root.homeSectionsVisible ? (root.expanded ? 6 : 3) : 0; searchPattern: root.searchText }

    Loader {
        id: folderLoader
        active: root.currentFolder.length > 0
        sourceComponent: RedesignFolderModel {
            folder: root.currentFolder
            nameFilters: DialogsProvider.mediaNameFilters(root.category === 2)
            sortReversed: root.descending
            sortCriteria: root.sortField
            searchPattern: root.searchText
        }
    }
    ListModel {
        id: musicCategories
        ListElement { title: QT_TR_NOOP("Songs"); iconName: "music" }
        ListElement { title: QT_TR_NOOP("Albums"); iconName: "music" }
        ListElement { title: QT_TR_NOOP("Artists"); iconName: "audio" }
        ListElement { title: QT_TR_NOOP("Genres"); iconName: "queue" }
    }
    MLAudioModel { id: music; ml: MediaLib; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLAlbumModel { id: albums; ml: MediaLib; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLArtistModel { id: artists; ml: MediaLib; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLGenreModel { id: genres; ml: MediaLib; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLAudioModel { id: collectionTracks; ml: MediaLib; parentId: root.selectedCollection || root.emptyParentId; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLRecentMediaModel { id: recent; ml: MediaLib; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder; searchPattern: root.searchText }
    MLPlaylistListModel { id: playlists; ml: MediaLib; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLPlaylistModel { id: playlistMedia; ml: MediaLib; parentId: root.selectedPlaylist || root.emptyParentId; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLUrlModel { id: streams; ml: MediaLib; searchPattern: root.searchText; sortCriteria: root.mediaSortField; sortOrder: root.mediaSortOrder }
    MLFolderModel { id: libraryFolders; ctx: MainCtx }
    ListModel { id: folderEntries }
    Connections { target: libraryFolders; function onModelReset() { root.refreshFolders() } }
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
