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
    property bool previewEnabled: false
    property url previewImage
    property real previewImagePosition: -1
    readonly property bool previewActive: enabled && visible && previewEnabled && (hovered || pressed || visualFocus)
    readonly property real previewPosition: pressed || visualFocus && !hovered ? value
        : Math.max(0, Math.min(1, (pointer.point.position.x - leftPadding - handle.width / 2) / Math.max(1, availableWidth - handle.width)))
    readonly property bool previewReady: previewActive && previewImage.toString().length > 0
        && previewImagePosition >= 0 && thumbnail.status === Image.Ready
    signal previewRequested(real position)
    signal previewEnded()
    function refreshPreview() {
        previewEnded()
        if (previewActive) previewDelay.restart()
    }
    onPreviewPositionChanged: if (previewActive && !previewDelay.running) previewDelay.start()
    onPreviewActiveChanged: {
        if (previewActive) previewDelay.restart()
        else { previewDelay.stop(); previewEnded() }
    }
    Component.onDestruction: previewEnded()
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
    Timer {
        id: previewDelay
        interval: 160
        onTriggered: if (root.previewActive) root.previewRequested(root.previewPosition)
    }
    C.Popup {
        id: preview
        objectName: "seekThumbnailPopup"
        visible: root.previewReady
        focus: false; modal: false
        closePolicy: C.Popup.NoAutoClose
        width: root.theme.dp(272); height: root.theme.dp(189)
        padding: root.theme.dp(10)
        x: {
            if (!root.Window.window) return 0
            const left = root.mapToItem(root.Window.window.contentItem, 0, 0).x
            return Math.max(-left, Math.min(root.previewPosition * root.width - width / 2, root.Window.window.width - left - width))
        }
        y: -height - root.theme.dp(12)
        background: Rectangle { radius: root.theme.dp(12); color: root.lightTheme ? root.theme.panel : "#191919" }
        contentItem: Item {
            Rectangle {
                width: parent.width; height: root.theme.dp(142); radius: root.theme.dp(4)
                color: "#000000"
                Image {
                    id: thumbnail
                    objectName: "seekThumbnailImage"
                    anchors.fill: parent
                    source: root.previewImage
                    cache: false
                    fillMode: Image.PreserveAspectFit
                }
            }
            Text {
                objectName: "seekThumbnailTime"
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeForPosition(root.previewImagePosition)
                font.pixelSize: root.theme.dp(14); color: root.theme.foreground
            }
        }
    }
    C.ToolTip.visible: root.enabled && (root.hovered || root.pressed || root.visualFocus) && !root.previewReady
    C.ToolTip.text: root.timeForPosition(root.previewPosition)
}
