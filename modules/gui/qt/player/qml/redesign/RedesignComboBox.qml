// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C

C.ComboBox {
    id: root
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    implicitHeight: theme.dp(34)
    font.pixelSize: theme.dp(14)
    leftPadding: theme.dp(14); rightPadding: theme.dp(40)
    contentItem: Text {
        text: root.displayText; font: root.font
        color: root.theme.foreground
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    background: Rectangle {
        radius: root.theme.dp(4); color: root.theme.background
        border.color: root.visualFocus ? root.theme.accent : root.theme.field
    }
    indicator: RedesignIcon {
        name: "chevron-down"; color: root.theme.foreground
        width: root.theme.dp(20); height: width
        x: root.width - width - root.theme.dp(14); y: (root.height - height) / 2
    }
    delegate: C.ItemDelegate {
        required property int index
        width: ListView.view.width
        implicitHeight: root.theme.dp(34)
        text: root.textAt(index)
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: parent.text; font: root.font; color: root.theme.foreground
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        background: Rectangle { radius: root.theme.dp(3); color: parent.highlighted ? root.theme.hover : "transparent" }
    }
    popup: C.Popup {
        y: root.height + root.theme.dp(4)
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, root.theme.dp(300))
        padding: root.theme.dp(4)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            C.ScrollIndicator.vertical: C.ScrollIndicator { }
        }
        background: Rectangle { color: root.theme.panel; radius: root.theme.dp(6); border.color: root.theme.border }
    }
}
