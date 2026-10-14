// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls.Basic as C

ColumnLayout {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var trackModel
    property string heading
    property bool allowDisable: false
    readonly property int count: choices.count
    readonly property bool hasSelection: {
        for (let i = 0; i < choices.count; ++i) {
            const row = choices.itemAt(i)
            if (row && row.checked) return true
        }
        return false
    }
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal selectionRequested(int index, bool selected)
    signal disableRequested()
    spacing: 0

    component TrackChoice: T.Button {
        id: choice
        property bool chosen: false
        Layout.fillWidth: true
        implicitHeight: root.theme.dp(44)
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        Accessible.role: Accessible.RadioButton
        Accessible.checkable: true
        Accessible.checked: chosen
        background: Rectangle {
            radius: root.theme.dp(4)
            color: choice.down || choice.hovered ? root.theme.hover : "transparent"
            border.width: choice.visualFocus ? 1 : 0
            border.color: root.theme.accent
        }
        contentItem: Item {
            RedesignIcon {
                objectName: "selectionMark"
                name: "check"
                visible: choice.chosen
                width: root.theme.dp(20); height: width
                anchors.left: parent.left
                anchors.leftMargin: root.theme.dp(24)
                anchors.verticalCenter: parent.verticalCenter
                color: root.theme.accent
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: root.theme.dp(62)
                anchors.right: parent.right; anchors.rightMargin: root.theme.dp(20)
                anchors.verticalCenter: parent.verticalCenter
                text: choice.text
                color: root.theme.foreground
                font.pixelSize: root.theme.dp(14)
                elide: Text.ElideRight
            }
        }
        C.ToolTip.text: text
        C.ToolTip.visible: hovered && text.length > 0
        C.ToolTip.delay: 650
    }
    Text {
        text: root.heading; color: theme.foreground; opacity: 0.75
        font.pixelSize: theme.dp(14)
        Layout.leftMargin: theme.dp(28)
        Layout.topMargin: theme.dp(22)
        Layout.bottomMargin: theme.dp(14)
    }
    TrackChoice {
        objectName: "disableTracks"
        visible: root.allowDisable
        text: qsTr("None")
        chosen: !root.hasSelection
        onClicked: root.disableRequested()
    }
    Repeater {
        id: choices
        model: root.trackModel
        Item {
            id: track
            required property int index
            required property string display
            required property bool checked
            Layout.fillWidth: true
            implicitHeight: root.theme.dp(44)
            TrackChoice {
                anchors.fill: parent
                objectName: "trackChoice_" + track.index
                text: track.display
                chosen: track.checked
                onClicked: root.selectionRequested(track.index, true)
            }
        }
    }
    Text {
        visible: choices.count === 0 && !root.allowDisable
        text: qsTr("No tracks available"); color: theme.foreground
        font.pixelSize: theme.dp(13)
        Layout.leftMargin: theme.dp(28); Layout.bottomMargin: theme.dp(16)
    }
}
