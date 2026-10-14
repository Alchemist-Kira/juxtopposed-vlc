// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Basic as C

T.Slider {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property bool muted: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    implicitWidth: theme.dp(90)
    implicitHeight: theme.dp(28)
    from: 0
    to: 1.25
    stepSize: 0.05
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: qsTr("Volume")
    padding: 0
    handle: Item { width: 0; height: 0 }
    background: Item {
        RedesignSvg {
            id: cone
            anchors.fill: parent
            opacity: root.muted ? 0.3 : 1
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            svg: {
                if (width <= 0 || height <= 0) return ""
                const path = "M2 " + (height * 0.35) + " L" + (width - 2) + " 1 Q" + width + " 1 " + width + " 4"
                    + " L" + width + " " + (height - 4) + " Q" + width + " " + (height - 1) + " " + (width - 2) + " " + (height - 1)
                    + " L2 " + (height * 0.65) + " Q0 " + (height * 0.65) + " 0 " + (height * 0.5) + " Z"
                return (
                    '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">'
                    + '<defs><clipPath id="cone"><path d="' + path + '"/></clipPath>'
                    + '<linearGradient id="volume" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="' + width + '" y2="0">'
                    + '<stop offset="0" stop-color="#6d9c00"/><stop offset="0.7" stop-color="#d4b400"/><stop offset="1" stop-color="#d37918"/>'
                    + '</linearGradient></defs><path d="' + path + '" fill="#090909"/>'
                    + '<rect x="2" y="2" width="' + Math.max(0, root.position * (width - 4)) + '" height="' + Math.max(0, height - 4)
                    + '" clip-path="url(#cone)" fill="url(#volume)"/></svg>')
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: theme.dp(4)
            border.width: root.visualFocus ? theme.dp(1) : 0
            border.color: theme.accent
        }
    }
    C.ToolTip.visible: root.hovered || root.visualFocus || root.pressed
    C.ToolTip.text: qsTr("%1%").arg(Math.round(value * 100))
}
