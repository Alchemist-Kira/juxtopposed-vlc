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
    ListModel { id: emptyHomeItems }
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
    Component { id: pinsComponent; RedesignLibraryPins { ctx: settings } }
    RedesignLibraryPath { id: folderPath }
    SignalSpy { id: homeSpy; target: library; signalName: "homeActivated" }
    SignalSpy { id: homeQueueSpy; target: library; signalName: "homeEnqueueRequested" }
    SignalSpy { id: sectionSpy; target: library; signalName: "homeSectionRequested" }
    SignalSpy { id: addSpy; target: library; signalName: "addRequested" }
    SignalSpy { id: playlistSpy; target: library; signalName: "newPlaylistRequested" }
    SignalSpy { id: settingsSpy; target: library; signalName: "preferencesRequested" }
    SignalSpy { id: activateSpy; target: library; signalName: "activated" }
    SignalSpy { id: categorySpy; target: library; signalName: "categoryRequested" }
    SignalSpy { id: breadcrumbSpy; target: library; signalName: "breadcrumbActivated" }
    SignalSpy { id: pinSpy; target: library; signalName: "pinActivated" }
    SignalSpy { id: pinRemoveSpy; target: library; signalName: "pinRemoved" }
    SignalSpy { id: pinQueueSpy; target: library; signalName: "pinEnqueueRequested" }
    function init() {
        testCase.width = 427
        testCase.Window.window.width = 427
        testCase.height = 986
        testCase.Window.window.height = 986
        wait(20)
        queueDrop.visible = false; queueDrop.drops = 0; queueDrop.sourceItem = null
        settings.saved = "[]"
        library.homeSections = []
        homeSpy.clear(); homeQueueSpy.clear(); sectionSpy.clear()
        library.category = 1
        library.grid = false
        library.scaleFactor = 1
        library.expanded = false
        library.searchText = ""
        library.breadcrumbs = []
        library.pins = []
        library.selectedPinId = ""
        library.forceActiveFocus()
        findChild(library, "libraryNavigationScroll").contentY = 0
        pinSpy.clear(); pinRemoveSpy.clear(); pinQueueSpy.clear()
        breadcrumbSpy.clear()
        library.sortState.saved = ({})
        library.sortFields = ["played", "insertion", "title", "main_artist", "album_title", "track_number", "uri", "disc_number"]
        library.canGoBack = false
        addSpy.clear(); playlistSpy.clear(); settingsSpy.clear()
        activateSpy.clear(); categorySpy.clear()
        wait(20)
    }
    function cleanup() {
        for (const name of ["libraryMoreMenu", "libraryViewMenu", "librarySortMenu", "libraryAncestorMenu", "libraryPinMenu"]) {
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
    function test_pinsPersistInOrderAndDoNotDuplicate() {
        let pins = createTemporaryObject(pinsComponent, testCase)
        const folder = {kind: "folder", key: "file:///Shows", name: "Shows", category: 1}
        const playlist = {kind: "playlist", key: "saved-playlist", name: "My songs"}
        pins.add(folder); pins.add(playlist)
        verify(pins.contains(folder))
        pins.add(Object.assign({}, folder, {name: "Renamed shows"}))
        compare(pins.entries.length, 2)
        compare(pins.entries[0].name, "Renamed shows")
        pins = createTemporaryObject(pinsComponent, testCase)
        compare(pins.entries[0].key, folder.key)
        compare(pins.entries[1].key, playlist.key)
        pins.toggle(folder)
        verify(!pins.contains(folder))
        compare(pins.entries[0].key, playlist.key)
        pins = createTemporaryObject(pinsComponent, testCase)
        compare(pins.entries.length, 1)
        compare(pins.entries[0].category, 4)
    }
    function test_pinsRejectInvalidSavedEntries() {
        const folder = {kind: "folder", key: "file:///Shows", name: "Shows"}
        settings.saved = JSON.stringify([null, {}, {kind: "invalid", key: "x", name: "x"}, {kind: "collection", key: "1", name: "x", section: "invalid"}, folder, folder])
        const pins = createTemporaryObject(pinsComponent, testCase)
        compare(pins.entries.length, 1)
        for (const value of ["invalid", "null", "42", "{}"]) {
            settings.saved = value
            compare(createTemporaryObject(pinsComponent, testCase).entries.length, 0)
        }
    }
    function test_pinnedShortcutsOpenQueueAndRemoveFromTheirMenu() {
        library.pins = [{id: "folder:shows", kind: "folder", key: "shows", name: "Shows", icon: "folder"}]
        const button = findChild(library, "libraryPin0")
        verify(button.visible)
        tryVerify(() => button.mapToItem(library, 0, 0).y === 282)
        mouseClick(button)
        compare(pinSpy.count, 1)
        compare(pinSpy.signalArguments[0][0].key, "shows")
        mouseClick(button, 10, 10, Qt.RightButton)
        const menu = findChild(library, "libraryPinMenu")
        tryCompare(menu, "opened", true)
        const queue = findChild(menu, "libraryAction_queue")
        verify(waitForRendering(queue))
        mouseClick(queue)
        compare(pinQueueSpy.count, 1)
        button.forceActiveFocus()
        keyClick(Qt.Key_Menu)
        tryCompare(menu, "opened", true)
        const remove = findChild(menu, "libraryAction_remove")
        verify(waitForRendering(remove))
        mouseClick(remove)
        compare(pinRemoveSpy.count, 1)
        compare(pinRemoveSpy.signalArguments[0][0].key, "shows")
        library.selectedPinId = "folder:shows"
        verify(button.selected)
        expandLibrary()
        compare(findChild(library, "libraryPin0").text, "Shows")
        verify(findChild(library, "libraryPin0").selected)
    }
    function test_manyPinsKeepAddAndKeyboardFocusInView() {
        const pins = []
        for (let i = 0; i < 30; ++i) pins.push({id: "folder:" + i, kind: "folder", key: i.toString(), name: "Folder " + i, icon: "folder"})
        library.pins = pins
        const scroll = findChild(library, "libraryNavigationScroll")
        tryVerify(() => scroll.contentHeight > scroll.height)
        const button = findChild(library, "libraryPin29")
        button.forceActiveFocus()
        verify(scroll.contentY > 0)
        const add = findChild(library, "libraryCategory6")
        add.forceActiveFocus()
        verify(add.mapToItem(scroll, 0, add.height).y <= scroll.height)
        keyClick(Qt.Key_Space)
        compare(addSpy.count, 1)
        library.pins = []
        tryCompare(scroll, "contentY", 0)
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
        compare(library.nameFromUrl("file:///"), "/")
    }
    function test_folderPathAncestors_data() {
        return [
            {tag: "registered-root", url: "file:///media/Shows/The%20Wand/S01/", roots: ["file:///media/Shows/"], expected: ["file:///media/Shows", "file:///media/Shows/The%20Wand", "file:///media/Shows/The%20Wand/S01"]},
            {tag: "longest-root", url: "file:///media/Shows/The%20Wand/S01", roots: ["file:///media/Shows", "file:///media/Shows/The Wand"], expected: ["file:///media/Shows/The%20Wand", "file:///media/Shows/The%20Wand/S01"]},
            {tag: "segment-boundary", url: "file:///Shows2/S01", roots: ["file:///Shows"], expected: ["file:///", "file:///Shows2", "file:///Shows2/S01"]},
            {tag: "raw-special-characters", url: "/media/20% off/Cat #1", roots: ["/media"], expected: ["file:///media", "file:///media/20%25%20off", "file:///media/20%25%20off/Cat%20%231"]},
            {tag: "drive", url: "C:\\Movies\\Cat #1\\", roots: [], expected: ["file:///C:", "file:///C:/Movies", "file:///C:/Movies/Cat%20%231"]},
            {tag: "drive-root-case", url: "file:///C:/Movies/Cat", roots: ["file:///c:/movies/"], expected: ["file:///C:/Movies", "file:///C:/Movies/Cat"]},
            {tag: "unc-share", url: "\\\\OtherPC\\Movies\\Cat", roots: [], expected: ["file://otherpc/Movies", "file://otherpc/Movies/Cat"]},
            {tag: "unc-root", url: "file://OtherPC/Movies/Cat", roots: ["\\\\OtherPC\\Movies"], expected: ["file://otherpc/Movies", "file://otherpc/Movies/Cat"]},
            {tag: "unicode", url: "file:///media/%E7%8C%AB/%2520", roots: ["/media/猫"], expected: ["file:///media/%E7%8C%AB", "file:///media/%E7%8C%AB/%2520"]},
            {tag: "filesystem-root", url: "file:///", roots: [], expected: ["file:///"]}
        ]
    }
    function test_folderPathAncestors(data) {
        compare(folderPath.trail(data.url, data.roots), data.expected)
        compare(folderPath.location(data.url), data.expected[data.expected.length - 1])
    }
    function test_breadcrumbsKeepHiddenAncestorsAvailable() {
        library.breadcrumbs = [{label: "Videos"}, {label: "Shows"}, {label: "The Wand"}, {label: "S01"}]
        const location = findChild(library, "libraryLocation")
        tryVerify(() => location.firstVisible > 0)
        const current = findChild(location, "libraryPath3")
        verify(current.visible)
        verify(!current.enabled)
        verify(current.width > 0)
        verify(!current.contentItem.truncated)
        const overflow = findChild(location, "libraryPathOverflow")
        mouseClick(overflow)
        const menu = findChild(location, "libraryAncestorMenu")
        tryCompare(menu, "opened", true)
        compare(menu.count, location.firstVisible)
        const first = findChild(menu, "libraryAction_0")
        tryVerify(() => first.visible)
        verify(waitForRendering(first))
        mouseClick(first)
        tryCompare(breadcrumbSpy, "count", 1)
        compare(breadcrumbSpy.signalArguments[0][0], 0)
        expandLibrary()
        const expanded = findChild(library, "libraryLocation")
        compare(expanded.firstVisible, 0)
        verify(!findChild(expanded, "libraryPathOverflow").visible)
        mouseClick(findChild(expanded, "libraryPath1"))
        compare(breadcrumbSpy.count, 2)
        compare(breadcrumbSpy.signalArguments[1][0], 1)
        const parent = findChild(expanded, "libraryPath2")
        parent.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(breadcrumbSpy.count, 3)
        compare(breadcrumbSpy.signalArguments[2][0], 2)
        compare(findChild(expanded, "libraryPath3").font.weight, Font.DemiBold)
        for (let i = 0; i < 4; ++i) {
            const button = findChild(expanded, "libraryPath" + i)
            verify(!button.contentItem.truncated, button.text + ": " + button.width + "/" + button.contentItem.implicitWidth)
        }
        const oldWidth = expanded.widths[0]
        library.scaleFactor = 1.25
        tryVerify(() => expanded.widths[0] > oldWidth * 1.2)
        for (let i = 0; i < 4; ++i) verify(!findChild(expanded, "libraryPath" + i).contentItem.truncated)
    }
    function test_breadcrumbsElideLongCurrentFolder() {
        library.breadcrumbs = [{label: "Videos"}, {label: "A folder name that is much longer than the compact library toolbar"}]
        const location = findChild(library, "libraryLocation")
        compare(location.firstVisible, 1)
        const current = findChild(location, "libraryPath1")
        verify(current.width > 0)
        verify(current.width < current.implicitWidth)
        verify(current.mapToItem(location, current.width, 0).x <= location.width)
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
    function expandLibrary() {
        testCase.width = 1920; testCase.height = 1040
        testCase.Window.window.width = 1920; testCase.Window.window.height = 1040
        library.expanded = true
        wait(20)
    }
    function test_expandedNavigationAndToolbarKeepSearchOnCollapse() {
        expandLibrary()
        const navigation = findChild(library, "libraryNavigation")
        compare(navigation.width, 201)
        compare(navigation.x, 8)
        compare(findChild(library, "libraryCategory2").caption, "Music")
        mouseClick(findChild(library, "libraryCategory2"))
        compare(categorySpy.signalArguments[0][0], 2)
        const search = findChild(library, "librarySearchField")
        verify(search.visible)
        mouseClick(search)
        keyClick(Qt.Key_S)
        compare(library.searchText, "s")
        library.expanded = false
        tryCompare(navigation, "width", 50)
        const compactSearch = findChild(library, "librarySearchField")
        tryVerify(() => compactSearch.visible)
        compare(compactSearch.text, "s")
        compare(findChild(library, "libraryCategory2").caption, "")
    }
    function test_expandedGridAndListMatchReferenceAndActivateSameItem() {
        expandLibrary()
        library.grid = true
        wait(20)
        const artwork = findChild(library, "libraryArtwork0")
        tryCompare(artwork, "width", 316)
        compare(artwork.height, 177.75)
        compare(artwork.mapToItem(library, 0, 0).x, 237)
        compare(artwork.mapToItem(library, 0, 0).y, 91)
        verify(!findChild(library, "libraryAddRow").visible)
        const second = findChild(library, "libraryMediaItem1")
        compare(second.mapToItem(library, 0, 0).x, 573)
        mouseClick(second)
        compare(activateSpy.signalArguments[0][0], 1)
        library.grid = false
        wait(20)
        tryCompare(second, "height", 42)
        compare(second.mapToItem(library, 0, 0).x, 653)
        mouseClick(second)
        compare(activateSpy.count, 2)
        compare(activateSpy.signalArguments[1][0], 1)
        library.expanded = false
        tryCompare(second, "width", findChild(library, "libraryMediaView").width)
    }
    function test_expandedLibraryKeepsControlsInsideNarrowWindow() {
        testCase.width = 640
        testCase.Window.window.width = 640
        library.expanded = true
        library.grid = true
        wait(20)
        const button = findChild(library, "libraryViewButton")
        const position = button.mapToItem(library, button.width, 0)
        verify(position.x <= library.width)
        mouseClick(button)
        tryCompare(findChild(library, "libraryViewMenu"), "opened", true)
        mouseClick(findChild(library, "libraryAction_list"))
        compare(library.grid, false)
    }
    function test_expandedHomeUsesMediaCardsAndKeepsMoreThanThreeItems() {
        expandLibrary()
        library.category = 0
        library.homeSections = [
            {key: "watching", title: "Continue Watching", model: homeItems, icon: "video", emptyText: "None"},
            {key: "listening", title: "Listen Again", model: homeItems, icon: "music", emptyText: "None"},
            {key: "folders", title: "Frequently Visited Folders", model: emptyHomeItems, icon: "folder", emptyText: "No folders"}
        ]
        const home = findChild(library, "libraryHomeView")
        wait(20)
        const video = findChild(home, "homeArtwork_watching_0")
        const music = findChild(home, "homeArtwork_listening_0")
        tryCompare(video, "width", 316)
        compare(video.height, 177.75)
        compare(music.width, 200)
        compare(music.height, 200)
        const first = findChild(home, "homeSection_watching")
        const next = findChild(home, "homeSection_listening")
        compare(first.mapToItem(library, 0, 0).y, 112)
        compare(next.mapToItem(home, 0, 0).y - first.mapToItem(home, 0, 0).y, 337.75)
        const fourth = findChild(home, "homeItem_watching_3")
        verify(fourth.visible)
        mouseClick(fourth)
        compare(homeSpy.signalArguments[0][1], 3)
        fourth.libraryView.enqueueRequested(fourth.mediaIndex)
        compare(homeQueueSpy.signalArguments[0][1], 3)
        compare(findChild(home, "homeItem_listening_0").text, "First")
        library.expanded = false
        tryCompare(fourth, "visible", false)
        compare(findChild(home, "homeItem_listening_0").text, "First - Artist")
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
