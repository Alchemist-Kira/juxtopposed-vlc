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
        Canvas {
            id: cone
            anchors.fill: parent
            opacity: root.muted ? 0.3 : 1
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(2, height * 0.35)
                ctx.lineTo(width - 2, 1)
                ctx.quadraticCurveTo(width, 1, width, 4)
                ctx.lineTo(width, height - 4)
                ctx.quadraticCurveTo(width, height - 1, width - 2, height - 1)
                ctx.lineTo(2, height * 0.65)
                ctx.quadraticCurveTo(0, height * 0.65, 0, height * 0.5)
                ctx.closePath()
                ctx.fillStyle = "#090909"
                ctx.fill()
                ctx.save()
                ctx.clip()
                const gradient = ctx.createLinearGradient(0, 0, width, 0)
                gradient.addColorStop(0, "#6d9c00")
                gradient.addColorStop(0.7, "#d4b400")
                gradient.addColorStop(1, "#d37918")
                ctx.fillStyle = gradient
                ctx.fillRect(2, 2, Math.max(0, root.position * (width - 4)), height - 4)
                ctx.restore()
            }
            Connections {
                target: root
                function onValueChanged() { cone.requestPaint() }
                function onWidthChanged() { cone.requestPaint() }
                function onHeightChanged() { cone.requestPaint() }
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
