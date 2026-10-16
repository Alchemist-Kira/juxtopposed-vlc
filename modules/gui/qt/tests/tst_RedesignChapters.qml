// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedChapters"
    width: 420; height: 600
    visible: true; when: windowShown
    ListModel { id: chapters }
    RedesignChaptersView {
        id: view
        width: 400; height: 550
        chaptersModel: chapters
    }
    SignalSpy { id: selected; target: view; signalName: "chapterRequested" }
    function item(name) { return findChild(view, name) }
    function init() {
        chapters.clear()
        chapters.append({display: "Winter", checked: false, time: 135})
        chapters.append({display: "Spring", checked: false, time: 1785})
        chapters.append({display: "Summer", checked: false, time: 3090})
        chapters.append({display: "Fall", checked: false, time: 4430})
        chapters.append({display: "Winter (5 Years Later)", checked: false, time: 6250})
        view.currentIndex = -1; view.keyboardNavigation = false
        view.width = 400; view.height = 550; view.scaleFactor = 1
        view.lightTheme = false; view.accentColor = "#d37918"
        selected.clear(); mouseMove(testCase, 415, 590); wait(20)
    }
    function test_referenceNumbersNamesAndTimes() {
        compare(item("chapterNumber0").text, "1")
        compare(item("chapterNumber4").text, "5")
        compare(item("chapterTime0").text, "00:02:15")
        compare(item("chapterTime4").text, "01:44:10")
        compare(item("chapterRow0").height, 44)
        compare(item("chapterRow0").mapToItem(view, 0, 0).x, 20)
        compare(item("chapterTitle0").mapToItem(view, 0, 0).x, 68)
        compare(item("chapterNumber0").color, "#d37918")
        mouseClick(item("chapterRow2"))
        compare(selected.count, 1); compare(selected.signalArguments[0][0], 2)
        verify(view.activeFocus); compare(view.currentIndex, 2)
    }
    function test_keyboardNavigationDoesNotSeekUntilActivation() {
        view.forceActiveFocus()
        keyClick(Qt.Key_Down); compare(view.currentIndex, 0)
        keyClick(Qt.Key_Down); compare(view.currentIndex, 1)
        keyClick(Qt.Key_Up); compare(view.currentIndex, 0)
        compare(selected.count, 0)
        keyClick(Qt.Key_Return); compare(selected.count, 1)
        compare(selected.signalArguments[0][0], 0)
        keyClick(Qt.Key_Space); compare(selected.count, 2)
        keyClick(Qt.Key_Up); compare(view.currentIndex, 0)
    }
    function test_playbackSelectionAndMediaResetDoNotUseOldRow() {
        chapters.setProperty(3, "checked", true)
        tryCompare(view, "currentIndex", 3)
        verify(item("chapterRow3").selected)
        view.forceActiveFocus(); keyClick(Qt.Key_Up)
        chapters.setProperty(4, "checked", true)
        compare(view.currentIndex, 2)
        chapters.clear()
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Up); keyClick(Qt.Key_Down)
        compare(selected.count, 0); compare(view.currentIndex, -1)
    }
    function test_narrowLightThemeKeepsTimeAndNumberVisible() {
        view.width = 290; view.lightTheme = true; view.accentColor = "#19a234"
        chapters.setProperty(0, "display", "A long chapter title that must fit beside the time")
        wait(20)
        const stamp = item("chapterTime0"), position = stamp.mapToItem(view, 0, 0)
        verify(position.x + stamp.width <= view.width - 23)
        compare(item("chapterNumber0").color, "#19a234")
        compare(item("chapterTitle0").color, "#404040")
        compare(view.clockText(90061), "25:01:01")
        compare(view.clockText(-1), "--:--:--")
        compare(view.clockText(undefined), "--:--:--")
        compare(view.clockText({}), "--:--:--")
    }
}
