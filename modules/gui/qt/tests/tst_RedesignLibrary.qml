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
    SignalSpy { id: addSpy; target: library; signalName: "addRequested" }
    SignalSpy { id: playlistSpy; target: library; signalName: "newPlaylistRequested" }
    SignalSpy { id: settingsSpy; target: library; signalName: "preferencesRequested" }
    function init() {
        library.category = 1
        library.grid = false
        library.canGoBack = false
        addSpy.clear(); playlistSpy.clear(); settingsSpy.clear()
    }
    function cleanup() {
        for (const name of ["libraryMoreMenu", "libraryViewMenu"]) {
            const menu = findChild(library, name)
            menu.close()
            tryCompare(menu, "opened", false)
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
}
