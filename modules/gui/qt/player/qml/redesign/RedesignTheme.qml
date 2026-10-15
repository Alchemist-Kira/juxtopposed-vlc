// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

QtObject {
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    readonly property color background: lightTheme ? "#acacac" : "#1b1b1b"
    readonly property color panel: lightTheme ? "#c3c3c3" : "#101010"
    readonly property color floatingPanel: lightTheme ? Qt.rgba(195 / 255, 195 / 255, 195 / 255, 0.95) : Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.95)
    readonly property color field: lightTheme ? "#dedede" : "#090909"
    readonly property color border: lightTheme ? "#969696" : "#292929"
    readonly property color foreground: lightTheme ? "#404040" : "#8f8f8f"
    readonly property color bright: lightTheme ? "#2e2e2e" : "#e5e5e5"
    readonly property color hover: lightTheme ? "#d5d5d5" : "#292929"
    readonly property color selected: lightTheme ? "#b8b8b8" : "#333333"
    readonly property color accent: accentColor
    readonly property color menuAccent: accentColor.toString() === "#d37918" ? "#ab6314" : Qt.darker(accentColor, 1.23)
    readonly property color progress: lightTheme ? "#d8ba9a" : "#371f06"
    readonly property color danger: "#d33718"
    readonly property color dangerBackground: lightTheme ? "#f8e2d9" : "#1a1111"

    function dp(value: real): real { return value * scaleFactor }
}
