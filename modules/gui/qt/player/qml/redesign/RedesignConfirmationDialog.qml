// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

C.Dialog {
    id: root
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    property string message
    property string confirmText: qsTr("Continue")
    property bool destructive: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    anchors.centerIn: parent
    width: Math.min(theme.dp(460), parent ? parent.width - theme.dp(32) : theme.dp(460))
    padding: theme.dp(24)
    modal: true; dim: true; focus: true
    closePolicy: C.Popup.CloseOnEscape
    header: null; footer: null
    background: Rectangle { color: root.theme.panel; radius: root.theme.dp(12); border.color: root.theme.border }
    onOpened: cancelButton.forceActiveFocus()
    contentItem: ColumnLayout {
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title
        spacing: root.theme.dp(20)
        Text {
            Layout.fillWidth: true
            text: root.title; color: root.theme.bright; font.pixelSize: root.theme.dp(20)
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: root.message; color: root.theme.foreground; font.pixelSize: root.theme.dp(14)
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.dp(8)
            Item { Layout.fillWidth: true }
            RedesignButton {
                id: cancelButton
                objectName: "confirmationCancel"
                Layout.preferredWidth: root.theme.dp(100); Layout.preferredHeight: root.theme.dp(36)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                caption: qsTr("Cancel"); text: caption
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.background; radius: root.theme.dp(4); border.color: parent.visualFocus ? root.theme.accent : "transparent" }
                onClicked: root.reject()
                Keys.onReturnPressed: root.reject()
                Keys.onEnterPressed: root.reject()
            }
            RedesignButton {
                objectName: "confirmationAccept"
                Layout.preferredWidth: root.theme.dp(100); Layout.preferredHeight: root.theme.dp(36)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                caption: root.confirmText; text: caption
                foreground: root.destructive ? root.theme.danger : root.theme.accent
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.destructive ? root.theme.dangerBackground : root.theme.progress; radius: root.theme.dp(4); border.color: parent.visualFocus ? parent.foreground : "transparent" }
                onClicked: root.accept()
                Keys.onReturnPressed: root.accept()
                Keys.onEnterPressed: root.accept()
            }
        }
    }
}
