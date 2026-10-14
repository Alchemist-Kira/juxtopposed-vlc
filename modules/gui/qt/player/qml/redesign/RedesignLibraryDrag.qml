// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window

Item {
    id: root
    required property DragHandler handler
    required property var libraryView
    required property int mediaIndex
    // Attached drags follow their item's position. Keep the source row in place
    // and move this empty proxy in window coordinates instead.
    parent: handler.parent.Window.window ? handler.parent.Window.window.contentItem : handler.parent
    width: 1; height: 1
    Drag.active: false
    Drag.source: root
    Drag.supportedActions: Qt.CopyAction
    Drag.keys: ["vlc-redesign-library"]
    Drag.hotSpot: Qt.point(0, 0)
    function followPointer() {
        x = handler.centroid.scenePosition.x
        y = handler.centroid.scenePosition.y
    }
    Connections {
        target: root.handler
        function onCentroidChanged() { if (root.handler.active) root.followPointer() }
        function onActiveChanged() {
            if (root.handler.active) {
                root.followPointer()
                root.Drag.active = true
            } else {
                root.Drag.drop()
                root.Drag.active = false
            }
        }
    }
    Component.onDestruction: if (Drag.active) Drag.cancel()
}
