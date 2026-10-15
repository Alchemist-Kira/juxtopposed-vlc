// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedAddToPlaylist"
    width: 1280; height: 800
    visible: true; when: windowShown
    ListModel {
        id: playlists
        Component.onCompleted: append([
            {id: "playlist-17", name: "Films", thumbnail: "", readOnly: false},
            {id: "playlist-23", name: "Films", thumbnail: "", readOnly: false},
            {id: "playlist-31", name: "Imported", thumbnail: "", readOnly: true}
        ])
    }
    RedesignAddToPlaylistDialog { id: dialog; parent: testCase; playlistModel: playlists }
    SignalSpy { id: saveSpy; target: dialog; signalName: "saveRequested" }
    function init() {
        width = 1280; height = 800
        dialog.busy = false; dialog.close(); saveSpy.clear()
        dialog.begin(2); tryCompare(dialog, "opened", true)
    }
    function cleanup() { dialog.busy = false; dialog.close(); tryCompare(dialog, "visible", false) }
    function row(index) {
        const list = findChild(dialog, "playlistDestinations")
        tryVerify(() => list.itemAtIndex(index) !== null)
        return list.itemAtIndex(index)
    }
    function test_existingPlaylistUsesIdentityRatherThanDuplicateName() {
        verify(!findChild(dialog, "addToPlaylistSave").enabled)
        mouseClick(row(1)); compare(dialog.selectedKey, "playlist-23")
        mouseClick(findChild(dialog, "addToPlaylistSave"))
        compare(saveSpy.signalArguments[0][0], "playlist-23"); compare(saveSpy.signalArguments[0][1], "")
        verify(dialog.busy)
    }
    function test_newNameAndExistingDestinationAreExclusive() {
        mouseClick(row(0)); dialog.newName = " New playlist "
        compare(dialog.selectedKey, "")
        dialog.submit(); compare(saveSpy.signalArguments[0][0], ""); compare(saveSpy.signalArguments[0][1], "New playlist")
        dialog.finish(false, "Retry")
        mouseClick(row(1)); compare(dialog.newName, ""); compare(dialog.selectedKey, "playlist-23")
        dialog.submit(); compare(saveSpy.signalArguments[1][0], "playlist-23"); compare(saveSpy.signalArguments[1][1], "")
    }
    function test_readOnlyDestinationCannotBeSelected() {
        verify(!row(2).enabled)
        mouseClick(row(2)); compare(dialog.selectedKey, ""); verify(!dialog.valid)
    }
    function test_searchClearsStaleDestination() {
        mouseClick(row(0)); dialog.filterText = "other"
        compare(dialog.selectedKey, ""); verify(!dialog.valid)
    }
    function test_busyPreventsDuplicateSubmitAndDismissal() {
        mouseClick(row(0)); dialog.submit(); dialog.submit()
        compare(saveSpy.count, 1)
        verify(!findChild(dialog, "addToPlaylistCancel").enabled)
        verify(!findChild(dialog, "addToPlaylistClose").enabled)
        verify(!findChild(dialog, "addToPlaylistName").enabled)
        keyClick(Qt.Key_Escape); verify(dialog.visible)
        verify(!dialog.begin(5)); compare(dialog.itemCount, 2); compare(dialog.selectedKey, "playlist-17")
    }
    function test_errorRetainsChoiceAndCanRetry() {
        dialog.newName = "Retry"; dialog.submit(); dialog.finish(false, "Cannot write")
        verify(dialog.visible); verify(!dialog.busy); compare(dialog.newName, "Retry")
        compare(dialog.errorMessage, "Cannot write")
        verify(findChild(dialog, "addToPlaylistError").visible)
        dialog.submit(); compare(saveSpy.count, 2)
        dialog.finish(true, ""); tryCompare(dialog, "visible", false)
    }
    function test_smallWindowKeepsFooterAndErrorVisible() {
        width = 560; height = 430
        dialog.newName = "Retry"; dialog.submit(); dialog.finish(false, "The selected playlist is no longer available.")
        verify(dialog.width <= width - 32); verify(dialog.height <= height - 32)
        const save = findChild(dialog, "addToPlaylistSave")
        const point = save.mapToItem(testCase, 0, 0)
        verify(point.y >= 0 && point.y + save.height <= height)
        verify(findChild(dialog, "addToPlaylistError").visible)
    }
    function test_reopenStartsWithNoDestinationOrName() {
        dialog.newName = "Old draft"; dialog.filterText = "old"; dialog.close()
        tryCompare(dialog, "visible", false)
        dialog.begin(1); tryCompare(dialog, "opened", true)
        compare(dialog.newName, ""); compare(dialog.filterText, ""); compare(dialog.selectedKey, "")
    }
}
