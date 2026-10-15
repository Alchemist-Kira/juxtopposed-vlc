// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as C
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedToolTip"
    width: 600; height: 400
    visible: true; when: windowShown
    RedesignButton { id: button; x: 20; y: 100; text: "Playback settings" }
    Window {
        id: offscreenWindow
        property var renderWindow: testCase.Window.window
        width: 300; height: 200
        visible: false
        RedesignButton { id: offscreenButton; text: "Audio" }
    }
    function init() {
        testCase.Window.window.visibility = Window.Windowed
        button.scaleFactor = 1; button.lightTheme = false
        const tip = findChild(button, "redesignToolTip")
        tip.close(); mouseMove(testCase, 400, 300)
    }
    function cleanup() {
        findChild(button, "redesignToolTip").close()
        testCase.Window.window.visibility = Window.Windowed
    }
    function test_hoverUsesThemeAndApplicationFont() {
        const tip = findChild(button, "redesignToolTip")
        mouseMove(button, button.width / 2, button.height / 2)
        tryCompare(tip, "opened", true, 2000)
        compare(tip.text, button.text)
        compare(tip.background.color, button.theme.panel)
        compare(tip.contentItem.color, button.theme.bright)
        compare(tip.font.family, Qt.application.font.family)
        compare(tip.font.pixelSize, 12)
        compare(tip.popupType, C.Popup.Window)
        button.lightTheme = true; button.scaleFactor = 1.5
        compare(tip.background.color, button.theme.panel)
        compare(tip.font.pixelSize, 18)
    }
    function test_offscreenRenderingUsesAnItemPopup() {
        const tip = findChild(offscreenButton, "redesignToolTip")
        compare(tip.hostWindow, testCase.Window.window)
        compare(tip.popupType, C.Popup.Item)
    }
    function test_fullscreenUsesTheControlsWindow() {
        const tip = findChild(button, "redesignToolTip")
        testCase.Window.window.visibility = Window.FullScreen
        compare(tip.popupType, C.Popup.Item)
        mouseMove(button, button.width / 2, button.height / 2)
        tryCompare(tip, "opened", true, 2000)
        compare(tip.popupType, C.Popup.Item)
    }
}
