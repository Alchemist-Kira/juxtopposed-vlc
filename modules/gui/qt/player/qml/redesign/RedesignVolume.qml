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
    // The audio level can exceed the slider's configured visual range.
    property real currentVolume: value
    signal wheelRequested(var event)
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
    // Keep wheel input separate from slider dragging: VLC's volume commands
    // can reach 200%, regardless of the configured drag range.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            root.wheelRequested(event)
            event.accepted = true
        }
    }
    background: Item {
        id: coneBackground
        // These sources depend only on geometry. Volume updates change the
        // clip, so neither SVG needs to be decoded or uploaded again.
        readonly property string artwork: {
            if (width <= 0 || height <= 0) return ""
            const path = "M2 " + (height * 0.35) + " L" + (width - 2) + " 1 Q" + width + " 1 " + width + " 4"
                + " L" + width + " " + (height - 4) + " Q" + width + " " + (height - 1) + " " + (width - 2) + " " + (height - 1)
                + " L2 " + (height * 0.65) + " Q0 " + (height * 0.65) + " 0 " + (height * 0.5) + " Z"
            return '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">'
                + '<defs><linearGradient id="volume" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="' + width + '" y2="0">'
                + '<stop offset="0" stop-color="#6d9c00"/><stop offset="0.7" stop-color="#d4b400"/><stop offset="1" stop-color="#d37918"/>'
                + '</linearGradient></defs><path d="' + path + '" fill="%FILL%"/></svg>'
        }
        Item {
            anchors.fill: parent
            opacity: root.muted ? 0.3 : 1
            RedesignSvg {
                objectName: "volumeConeBackground"
                anchors.fill: parent
                svg: coneBackground.artwork.replace("%FILL%", "#090909")
            }
            Item {
                objectName: "volumeConeClip"
                x: 2
                width: root.position * Math.max(0, coneBackground.width - 4)
                height: parent.height
                clip: true
                RedesignSvg {
                    objectName: "volumeConeFill"
                    x: -2
                    width: coneBackground.width
                    height: coneBackground.height
                    svg: coneBackground.artwork.replace("%FILL%", "url(#volume)")
                }
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
    RedesignToolTip { theme: root.theme; text: qsTr("%1%").arg(Math.round((root.pressed ? root.value : root.currentVolume) * 100)); visible: root.hovered || root.visualFocus || root.pressed; delay: 0 }
}
