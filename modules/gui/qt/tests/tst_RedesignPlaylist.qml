// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedPlaylist"
    width: 1280; height: 800
    visible: true; when: windowShown
    RedesignPlaylistDialog { id: dialog; parent: testCase }
    SignalSpy { id: saveSpy; target: dialog; signalName: "saveRequested" }
    SignalSpy { id: filesSpy; target: dialog; signalName: "filesRequested" }
    SignalSpy { id: coverSpy; target: dialog; signalName: "coverRequested" }
    function init() {
        width = 1280; height = 800
        dialog.scaleFactor = 1; dialog.lightTheme = false; dialog.busy = false
        dialog.close(); saveSpy.clear(); filesSpy.clear(); coverSpy.clear()
        dialog.begin(); tryCompare(dialog, "opened", true)
    }
    function cleanup() { dialog.busy = false; dialog.close(); tryCompare(dialog, "visible", false) }
    function test_nameRequiredButEmptyPlaylistAllowed() {
        const save = findChild(dialog, "playlistSaveButton")
        verify(!save.enabled)
        dialog.playlistName = " \t "; dialog.submit(); compare(saveSpy.count, 0)
        dialog.playlistName = " Empty playlist "
        mouseClick(save); compare(saveSpy.count, 1)
        compare(saveSpy.signalArguments[0][0], "Empty playlist")
        compare(saveSpy.signalArguments[0][1], [])
    }
    function test_filesKeepOrderDuplicatesAndEncodedPaths() {
        dialog.addFiles(["file:///video/second.mkv", "file:///video/first%20%26%20last.mkv", "file:///video/second.mkv", "relative.mkv"])
        compare(dialog.fileCount, 3)
        compare(dialog.urls, ["file:///video/second.mkv", "file:///video/first%20%26%20last.mkv", "file:///video/second.mkv"])
        const listing = findChild(dialog, "playlistSelectedFiles")
        tryVerify(() => listing.itemAtIndex(0) !== null)
        mouseClick(findChild(listing.itemAtIndex(0), "playlistRemoveFile0"))
        compare(dialog.urls, ["file:///video/first%20%26%20last.mkv", "file:///video/second.mkv"])
        dialog.playlistName = "Ordered"
        dialog.submit()
        compare(saveSpy.signalArguments[0][1], dialog.urls)
        dialog.addFiles(["file:///another.mkv"]); dialog.removeFile(0); dialog.submit()
        compare(dialog.fileCount, 2); compare(saveSpy.count, 1)
    }
    function test_fileAndCoverSelectors() {
        mouseClick(findChild(dialog, "playlistSelectFilesButton")); compare(filesSpy.count, 1)
        mouseClick(findChild(dialog, "playlistCoverButton")); compare(coverSpy.count, 1)
        dialog.cover = Qt.resolvedUrl("../pixmaps/prefs/spref_interface.png")
        verify(findChild(dialog, "playlistRemoveCoverButton").visible)
        mouseClick(findChild(dialog, "playlistRemoveCoverButton"))
        compare(dialog.cover.toString(), "")
        dialog.addFiles(["file:///video.mkv"])
        mouseClick(findChild(dialog, "playlistAddMoreFilesButton")); compare(filesSpy.count, 2)
    }
    function test_failurePreservesDraftAndAllowsRetry() {
        dialog.playlistName = "Retry"
        dialog.cover = Qt.resolvedUrl("../pixmaps/prefs/spref_interface.png")
        dialog.addFiles(["file:///video.mkv"])
        dialog.submit(); dialog.finish(false, "Cannot save")
        verify(dialog.visible); verify(!dialog.busy)
        compare(dialog.playlistName, "Retry"); compare(dialog.fileCount, 1)
        compare(dialog.errorMessage, "Cannot save")
        dialog.submit(); compare(saveSpy.count, 2)
        compare(saveSpy.signalArguments[0][2].toString(), dialog.cover.toString())
        dialog.finish(true); tryCompare(dialog, "visible", false)
    }
    function test_cancelDiscardsDraftOnNextOpen() {
        dialog.playlistName = "Draft"; dialog.addFiles(["file:///video.mkv"])
        mouseClick(findChild(dialog, "playlistCancelButton")); tryCompare(dialog, "visible", false)
        compare(saveSpy.count, 0)
        dialog.begin(); tryCompare(dialog, "opened", true)
        compare(dialog.playlistName, ""); compare(dialog.fileCount, 0)
    }
    function test_keyboardSaveAndBusyCannotClose() {
        dialog.playlistName = "Keyboard"
        keyClick(Qt.Key_Return, Qt.ControlModifier); compare(saveSpy.count, 1)
        keyClick(Qt.Key_Escape); verify(dialog.visible)
        dialog.finish(false, "Cannot save")
        keyClick(Qt.Key_Escape); tryCompare(dialog, "visible", false)
    }
    function test_scaledAndSmallWindow_data() {
        return [{tag:"small", w:500, h:400, scale:1}, {tag:"scaled", w:1280, h:800, scale:1.5}, {tag:"light", w:1280, h:800, scale:1, light:true}]
    }
    function test_errorStaysVisibleAboveButtonsInSmallWindow() {
        width = 500; height = 400
        dialog.playlistName = "Retry"; dialog.submit()
        dialog.finish(false, "VLC cannot read this image. Select another image.")
        wait(50)
        const error = findChild(dialog, "playlistErrorMessage"), save = findChild(dialog, "playlistSaveButton")
        const errorPoint = error.mapToItem(testCase, 0, 0), savePoint = save.mapToItem(testCase, 0, 0)
        verify(error.visible)
        verify(errorPoint.y >= 0 && errorPoint.y + error.height <= savePoint.y)
    }
    function test_scaledAndSmallWindow(data) {
        width = data.w; height = data.h; dialog.scaleFactor = data.scale; dialog.lightTheme = !!data.light
        wait(50)
        verify(dialog.x >= 0 && dialog.y >= 0)
        verify(dialog.x + dialog.width <= width && dialog.y + dialog.height <= height)
        for (const name of ["playlistCloseButton", "playlistSaveButton", "playlistCancelButton"]) {
            const button = findChild(dialog, name), point = button.mapToItem(testCase, 0, 0)
            verify(point.x >= 0 && point.y >= 0, name)
            verify(point.x + button.width <= width && point.y + button.height <= height, name)
        }
    }
}
