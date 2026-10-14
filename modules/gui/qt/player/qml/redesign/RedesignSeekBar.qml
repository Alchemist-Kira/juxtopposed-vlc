// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Basic as C

T.Slider {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var timeForPosition: function(position) { return "" }
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    implicitHeight: theme.dp(28)
    implicitWidth: theme.dp(200)
    padding: theme.dp(2)
    from: 0
    to: 1
    stepSize: 0.005
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: qsTr("Playback position")

    background: Rectangle {
        color: theme.field
        radius: theme.dp(6)
        border.color: root.visualFocus ? theme.accent : "transparent"
        border.width: theme.dp(1)
        Rectangle {
            x: root.leftPadding
            y: root.topPadding
            width: root.visualPosition * (root.availableWidth - root.handle.width) + root.handle.width
            height: root.availableHeight
            radius: theme.dp(4)
            color: theme.progress
            visible: root.value > 0
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding
        width: theme.dp(8)
        height: root.availableHeight
        radius: theme.dp(4)
        color: theme.accent
        opacity: root.enabled ? 1 : 0.35
    }
    HoverHandler { id: pointer }
    C.ToolTip.visible: root.enabled && (root.hovered || root.pressed || root.visualFocus)
    C.ToolTip.text: root.timeForPosition(root.pressed || root.visualFocus ? root.value : Math.max(0, Math.min(1, pointer.point.position.x / root.width)))
}
