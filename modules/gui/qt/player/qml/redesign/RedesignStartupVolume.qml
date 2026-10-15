// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

ColumnLayout {
    id: root
    required property var backend
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    readonly property bool remember: { backend.revision; return !!backend.value("volume-save") }
    readonly property int startupVolume: { backend.revision; return Number(backend.value("redesign-startup-volume")) }
    onRememberChanged: if (remember) {
        field.invalid = false
        field.text = startupVolume.toString()
    }
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    spacing: theme.dp(2)
    RedesignButton {
        objectName: "rememberStartupVolume"
        Layout.fillWidth: true; Layout.preferredHeight: theme.dp(38)
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        leftAligned: true; caption: qsTr("Remember last volume"); text: caption
        selected: root.remember
        Accessible.role: Accessible.RadioButton
        Accessible.checkable: true; Accessible.checked: selected
        background: Rectangle { color: parent.selected ? theme.progress : theme.background; radius: theme.dp(4); border.color: parent.visualFocus ? theme.accent : theme.field }
        onClicked: root.backend.stage("volume-save", true)
    }
    RowLayout {
        Layout.fillWidth: true; Layout.preferredHeight: theme.dp(36)
        spacing: 0
        RedesignButton {
            objectName: "fixedStartupVolume"
            Layout.preferredWidth: theme.dp(132); Layout.fillHeight: true
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            leftAligned: true; caption: qsTr("Always starts at:"); text: caption
            selected: !root.remember
            Accessible.role: Accessible.RadioButton
            Accessible.checkable: true; Accessible.checked: selected
            background: Rectangle { color: parent.selected ? theme.progress : theme.background; radius: theme.dp(4); border.color: parent.visualFocus ? theme.accent : theme.field }
            onClicked: root.backend.stage("volume-save", false)
        }
        C.TextField {
            id: field
            objectName: "startupVolumeField"
            Layout.fillWidth: true; Layout.fillHeight: true
            enabled: !root.remember
            opacity: enabled ? 1 : 0.5
            property bool invalid: false
            text: root.startupVolume.toString()
            color: invalid ? "#e56b6b" : theme.foreground
            font.pixelSize: theme.dp(14)
            leftPadding: theme.dp(12); rightPadding: theme.dp(30)
            selectByMouse: true
            inputMethodHints: Qt.ImhDigitsOnly
            Accessible.name: qsTr("Startup volume in percent")
            background: Rectangle { color: theme.field; radius: theme.dp(4); border.color: field.invalid ? "#e56b6b" : field.activeFocus ? theme.accent : theme.border }
            TextMetrics { id: valueMetrics; text: field.text; font: field.font }
            Text { x: field.leftPadding + valueMetrics.advanceWidth; anchors.verticalCenter: parent.verticalCenter; text: "%"; color: theme.foreground; font.pixelSize: theme.dp(14); visible: !field.activeFocus }
            onEditingFinished: invalid = !root.backend.stage("redesign-startup-volume", text)
            onActiveFocusChanged: if (activeFocus) selectAll()
            RedesignToolTip { theme: root.theme; text: qsTr("Volume on the next VLC startup (0–300%)."); visible: parent.hovered; delay: 0 }
        }
    }
}
