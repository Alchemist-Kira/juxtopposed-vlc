// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts

C.Menu {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var entries: []
    signal actionRequested(string action)
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    width: theme.dp(265)
    padding: theme.dp(4)
    margins: theme.dp(10)
    popupType: C.Popup.Item
    background: Rectangle {
        color: root.lightTheme ? root.theme.background : "#191919"
        radius: root.theme.dp(10)
    }
    Instantiator {
        model: root.entries
        delegate: C.MenuItem {
            id: row
            required property var modelData
            objectName: "libraryAction_" + modelData.action
            implicitHeight: root.theme.dp(48)
            leftPadding: root.theme.dp(14)
            rightPadding: root.theme.dp(14)
            text: modelData.label
            enabled: modelData.enabled !== false
            checkable: modelData.checked !== undefined
            checked: modelData.checked === true
            indicator: null
            arrow: null
            background: Rectangle { radius: root.theme.dp(6); color: row.highlighted ? root.theme.hover : "transparent" }
            contentItem: RowLayout {
                spacing: root.theme.dp(10)
                opacity: row.enabled ? 1 : 0.35
                RedesignIcon {
                    visible: !!row.modelData.icon
                    Layout.preferredWidth: root.theme.dp(24)
                    Layout.preferredHeight: root.theme.dp(24)
                    sourceSize: Qt.size(root.theme.dp(24) * Screen.devicePixelRatio, root.theme.dp(24) * Screen.devicePixelRatio)
                    name: row.modelData.icon || ""
                    color: root.theme.foreground
                }
                Text {
                    Layout.fillWidth: true
                    text: row.text
                    color: root.theme.foreground
                    font.pixelSize: root.theme.dp(14)
                    elide: Text.ElideRight
                }
                RedesignIcon {
                    visible: row.checkable
                    opacity: row.checked ? 1 : 0
                    Layout.preferredWidth: root.theme.dp(20)
                    Layout.preferredHeight: root.theme.dp(20)
                    sourceSize: Qt.size(root.theme.dp(20) * Screen.devicePixelRatio, root.theme.dp(20) * Screen.devicePixelRatio)
                    name: "check"
                    color: root.theme.accent
                }
            }
            onTriggered: root.actionRequested(modelData.action)
        }
        onObjectAdded: (index, object) => root.insertItem(index, object)
        onObjectRemoved: (index, object) => root.removeItem(object)
    }
}
