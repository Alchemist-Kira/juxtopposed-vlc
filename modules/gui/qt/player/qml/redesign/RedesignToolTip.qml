// SPDX-License-Identifier: GPL-2.0-or-later
// An explicit, styled tooltip. The shared attached C.ToolTip instance is unreliable to style
// (Qt 6.11 can hand out a different instance than the one configured), so redesign controls
// declare their own. Popup.Window lets KWin place it past the main window's edge.
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as C

C.ToolTip {
    id: tip
    objectName: "redesignToolTip"
    property RedesignTheme theme
    readonly property real s: theme ? theme.scaleFactor : 1

    // Windowed: a real popup so it is never clipped at the window edge. Fullscreen: in-window,
    // because a separate surface takes pointer hover from the main window and the auto-hiding
    // bars would hide under it (show/hide loop). The window is the whole screen there anyway.
    popupType: parent && parent.Window.window && parent.Window.window.visibility === Window.FullScreen
               ? C.Popup.Item : C.Popup.Window
    delay: 650
    margins: 6 * s
    padding: 6 * s
    leftPadding: 8 * s
    rightPadding: 8 * s
    font.family: Qt.application.font.family
    font.pixelSize: 12 * s

    contentItem: Text {
        text: tip.text
        font: tip.font
        color: tip.theme ? tip.theme.bright : "#e5e5e5"
        wrapMode: Text.Wrap
    }
    background: Rectangle {
        radius: 6 * tip.s
        color: tip.theme ? tip.theme.panel : "#101010"
        border.width: 1
        border.color: tip.theme ? tip.theme.border : "#292929"
    }
}
