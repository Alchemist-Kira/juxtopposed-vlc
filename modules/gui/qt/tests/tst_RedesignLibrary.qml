// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedLibrary"
    width: 427; height: 986
    visible: true
    when: windowShown
    RedesignLibraryView {
        id: library
        anchors.fill: parent
        mediaModel: ListModel {
            ListElement { title: "Shows"; fileIsDir: true }
            ListElement { title: "Films"; fileIsDir: true }
            ListElement { title: "Anime"; fileIsDir: true }
        }
    }
    ListModel {
        id: homeItems
        ListElement { title: "First"; main_artist: "Artist" }
        ListElement { title: "Second" }
        ListElement { title: "Third" }
        ListElement { title: "Fourth" }
    }
    QtObject {
        id: settings
        property string saved: "[]"
        function settingValue(key, fallback) { return saved }
        function setSettingValue(key, value) { saved = value }
    }
    DropArea {
        id: queueDrop
        x: 310; y: 700; width: 100; height: 100; z: 10
        visible: false
        keys: ["vlc-redesign-library"]
        property int drops: 0
        property var sourceItem
        onDropped: drop => { drops++; sourceItem = drop.source; drop.acceptProposedAction() }
    }
    Component { id: visitsComponent; RedesignLibraryVisits { ctx: settings } }
    Component { id: sortComponent; RedesignLibrarySort { ctx: settings } }
    SignalSpy { id: homeSpy; target: library; signalName: "homeActivated" }
    SignalSpy { id: homeQueueSpy; target: library; signalName: "homeEnqueueRequested" }
    SignalSpy { id: sectionSpy; target: library; signalName: "homeSectionRequested" }
    SignalSpy { id: addSpy; target: library; signalName: "addRequested" }
    SignalSpy { id: playlistSpy; target: library; signalName: "newPlaylistRequested" }
    SignalSpy { id: settingsSpy; target: library; signalName: "preferencesRequested" }
    function init() {
        testCase.height = 986
        testCase.Window.window.height = 986
        wait(20)
        queueDrop.visible = false; queueDrop.drops = 0; queueDrop.sourceItem = null
        settings.saved = "[]"
        library.homeSections = []
        homeSpy.clear(); homeQueueSpy.clear(); sectionSpy.clear()
        library.category = 1
        library.grid = false
        library.sortState.saved = ({})
        library.sortFields = ["played", "insertion", "title", "main_artist", "album_title", "track_number", "uri", "disc_number"]
        library.canGoBack = false
        addSpy.clear(); playlistSpy.clear(); settingsSpy.clear()
    }
    function cleanup() {
        for (const name of ["libraryMoreMenu", "libraryViewMenu", "librarySortMenu"]) {
            const menu = findChild(library, name)
            if (menu) { menu.close(); tryVerify(() => !menu || !menu.visible) }
        }
    }
    function test_sortMenuMatchesReferenceAndKeepsChoice() {
        const button = findChild(library, "librarySortButton")
        mouseClick(button)
        let menu = library.sortPopup
        tryCompare(menu, "opened", true)
        compare(menu.width, 265)
        compare(menu.count, 16)
        let first = findChild(menu, "libraryAction_unwatched")
        compare(first.height, 48)
        verify(first.checked)
        let track = findChild(menu, "libraryAction_track-desc")
        mouseClick(track)
        compare(library.sortField, "track_number")
        compare(library.descending, true)
        mouseClick(button)
        menu = library.sortPopup
        tryCompare(menu, "opened", true)
        track = findChild(menu, "libraryAction_track-desc")
        first = findChild(menu, "libraryAction_unwatched")
        verify(track.checked)
        verify(!first.checked)
        compare(button.iconName, "sort-active")
        keyClick(Qt.Key_Escape)
        tryCompare(library, "sortPopup", null)
    }
    function test_sortMenuRestrictsChoicesToFolderData() {
        library.sortFields = ["title", "insertion", "uri"]
        library.sortState.select("title-asc")
        mouseClick(findChild(library, "librarySortButton"))
        let menu = library.sortPopup
        tryCompare(menu, "opened", true)
        compare(menu.count, 6)
        verify(!findChild(library, "libraryAction_track-asc"))
        library.sortState.select("track-asc")
        compare(library.sortField, "title")
    }
    function test_sortMenuFitsSmallWindowAndReachesLastChoice() {
        testCase.height = 480
        testCase.Window.window.height = 480
        wait(20)
        mouseClick(findChild(library, "librarySortButton"))
        let menu = library.sortPopup
        tryCompare(menu, "opened", true)
        verify(menu.height <= testCase.height - 20)
        for (let i = 0; i < 15; ++i) keyClick(Qt.Key_Down)
        tryVerify(() => menu.contentItem.currentItem === menu.itemAt(15))
        keyClick(Qt.Key_Return)
        tryCompare(library, "sortField", "disc_number")
        compare(library.descending, true)
        testCase.height = 986
    }
    function test_sortChoicesPersistByViewAndSurviveReload() {
        settings.saved = "{}"
        let sort = createTemporaryObject(sortComponent, testCase, {scope: "folders", fields: ["title", "uri"], defaultChoice: "title-asc"})
        sort.select("uri-desc")
        compare(sort.selection.id, "uri-desc")
        sort.scope = "songs"
        sort.fields = ["title", "track_number"]
        compare(sort.selection.id, "title-asc")
        sort.select("track-asc")
        sort = createTemporaryObject(sortComponent, testCase, {scope: "folders", fields: ["title", "uri"], defaultChoice: "title-asc"})
        compare(sort.selection.id, "uri-desc")
        sort.scope = "songs"
        sort.fields = ["title", "track_number"]
        compare(sort.selection.id, "track-asc")
    }
    function test_sortChoicesRejectInvalidSavedData() {
        for (const value of ["invalid", "[]", "null", "42", '{"media":"unknown"}']) {
            settings.saved = value
            const sort = createTemporaryObject(sortComponent, testCase)
            compare(sort.selection.id, "unwatched")
        }
    }
    function test_folderNamesKeepLiteralPercents() {
        compare(library.nameFromUrl("/media/20% off/"), "20% off")
        compare(library.nameFromUrl("file:///media/20%25%20off/"), "20% off")
        compare(library.nameFromUrl("C:\\Media\\Shows\\"), "Shows")
        compare(library.nameFromUrl("file:///media/bad%escape/"), "bad%escape")
    }
    function test_addStaysAvailableAfterNavigation() {
        const add = findChild(library, "libraryAddRow")
        verify(add.visible)
        mouseClick(add)
        compare(addSpy.count, 1)
        library.category = 4
        library.canGoBack = true
        mouseClick(add)
        compare(playlistSpy.count, 1)
        library.category = 0
        verify(!add.visible)
        library.category = 5
        verify(!add.visible)
    }
    function test_viewMenuShowsAndChangesCurrentChoice() {
        const button = findChild(library, "libraryViewButton")
        mouseClick(button)
        tryCompare(findChild(library, "libraryViewMenu"), "opened", true)
        let grid = findChild(library, "libraryAction_grid")
        let list = findChild(library, "libraryAction_list")
        tryVerify(() => list.visible)
        verify(list.checked); verify(!grid.checked)
        mouseClick(grid)
        compare(library.grid, true)
        mouseClick(button)
        tryCompare(findChild(library, "libraryViewMenu"), "opened", true)
        grid = findChild(library, "libraryAction_grid")
        list = findChild(library, "libraryAction_list")
        tryVerify(() => grid.visible)
        verify(grid.checked); verify(!list.checked)
        mouseClick(list)
        compare(library.grid, false)
    }
    function test_headerSettingsAction() {
        mouseClick(findChild(library, "libraryMoreButton"))
        tryCompare(findChild(library, "libraryMoreMenu"), "opened", true)
        const item = findChild(library, "libraryAction_settings")
        tryVerify(() => item.visible)
        verify(waitForRendering(item))
        mouseClick(item)
        compare(settingsSpy.count, 1)
        compare(addSpy.count, 0)
    }
    function test_homeSeparatesSectionsAndLimitsTheirPreviews() {
        library.category = 0
        library.homeSections = [
            {key: "watching", title: "Continue Watching", model: homeItems, icon: "video", emptyText: "None"},
            {key: "listening", title: "Listen Again", model: homeItems, icon: "music", emptyText: "None"},
            {key: "folders", title: "Frequently Visited Folders", model: homeItems, icon: "folder", emptyText: "None"},
            {key: "playlists", title: "Frequently Visited Playlists", model: homeItems, icon: "queue", emptyText: "None"},
            {key: "artists", title: "Frequently Listened Artists", model: homeItems, icon: "artist", emptyText: "None"}
        ]
        const home = findChild(library, "libraryHomeView")
        verify(home.visible)
        const first = findChild(home, "homeItem_watching_0")
        tryVerify(() => first.visible)
        verify(waitForRendering(first))
        verify(!findChild(home, "homeItem_watching_3").visible)
        verify(!findChild(library, "libraryMediaView").visible)
        mouseClick(first)
        compare(homeSpy.signalArguments[0][0], "watching")
        compare(homeSpy.signalArguments[0][1], 0)
        first.libraryView.enqueueRequested(first.mediaIndex)
        compare(homeQueueSpy.signalArguments[0][0], "watching")
        compare(homeQueueSpy.signalArguments[0][1], 0)
        compare(findChild(home, "homeItem_listening_0").text, "First - Artist")
        const section = findChild(home, "homeSection_listening")
        mouseClick(section)
        compare(sectionSpy.signalArguments[0][0], "listening")
        const firstHeader = findChild(home, "homeSection_watching")
        compare(section.mapToItem(home, 0, 0).y - firstHeader.mapToItem(home, 0, 0).y, 192)
        home.contentY = 500
        verify(home.contentHeight > home.height)
    }
    function test_homeDragFollowsPointerToQueue() {
        library.category = 0
        library.homeSections = [{key: "watching", title: "Continue Watching", model: homeItems, icon: "video", emptyText: "None"}]
        queueDrop.visible = true
        const item = findChild(library, "homeItem_watching_0")
        tryVerify(() => item.visible)
        verify(waitForRendering(item))
        mousePress(item, 80, 20)
        mouseMove(testCase, 220, 300, 50)
        mouseMove(testCase, 340, 720, 50)
        mouseRelease(testCase, 340, 720)
        tryCompare(queueDrop, "drops", 1)
        compare(queueDrop.sourceItem.mediaIndex, 0)
        queueDrop.sourceItem.libraryView.enqueueRequested(0)
        compare(homeQueueSpy.signalArguments[0][0], "watching")
    }
    function test_visitsRankByFrequencyAndPersist() {
        let visits = createTemporaryObject(visitsComponent, testCase)
        visits.record("folders", "file:///Shows", "Shows")
        visits.record("folders", "file:///Films", "Films")
        visits.record("folders", "file:///Shows", "Shows")
        visits.record("playlists", "PLAYLIST - 4", "Favorites")
        compare(visits.ranked("folders", "")[0].key, "file:///Shows")
        compare(visits.ranked("folders", "SHO").length, 1)
        compare(visits.ranked("playlists", "").length, 1)
        visits.destroy()
        visits = createTemporaryObject(visitsComponent, testCase)
        compare(visits.ranked("folders", "")[0].count, 2)
        visits.record("playlists", "PLAYLIST - 4", "Renamed")
        compare(visits.ranked("playlists", "")[0].name, "Renamed")
        compare(visits.ranked("playlists", "").length, 1)
    }
    function test_savedVisitsAreRankedOnLoad() {
        settings.saved = JSON.stringify([
            {kind: "folders", key: "low", name: "Low", count: 1, last: 20},
            {kind: "folders", key: "high", name: "High", count: 3, last: 10}])
        const visits = createTemporaryObject(visitsComponent, testCase)
        compare(visits.ranked("folders", "")[0].key, "high")
    }
    function test_visitsRejectInvalidSavedData() {
        settings.saved = "not json"
        let visits = createTemporaryObject(visitsComponent, testCase)
        compare(visits.entries.length, 0)
        visits.destroy()
        settings.saved = JSON.stringify([{kind:"folders",key:"bad",name:"Bad",count:-1}, {kind:"bogus",key:"bad",name:"Bad",count:1}])
        visits = createTemporaryObject(visitsComponent, testCase)
        compare(visits.entries.length, 0)
        visits.record("folders", "", "Empty")
        compare(visits.entries.length, 0)
    }

}
