// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C

RowLayout {
    id: root
    required property var backend
    required property string optionName
    property string label
    property real scaleFactor: 1
    property bool lightTheme: false
    readonly property var description: backend.describe(optionName)
    readonly property var currentValue: { backend.revision; return backend.value(optionName) }
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme }
    readonly property bool available: description.kind !== undefined
    visible: available
    spacing: theme.dp(10)
    implicitHeight: available ? Math.max(theme.dp(42), labelText.implicitHeight + theme.dp(10)) : 0
    Text {
        id: labelText
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        text: root.label || root.description.title || ""
        color: theme.foreground
        font.pixelSize: theme.dp(14)
        wrapMode: Text.WordWrap
        C.ToolTip.text: root.description.help || ""
        C.ToolTip.visible: helpHover.hovered && C.ToolTip.text.length > 0
        C.ToolTip.delay: 500
        HoverHandler { id: helpHover }
    }
    Loader {
        Layout.preferredWidth: Math.min(theme.dp(320), Math.max(theme.dp(150), root.width * 0.43))
        Layout.preferredHeight: theme.dp(34)
        sourceComponent: root.description.kind === "bool" ? toggleEditor
            : root.description.choices && root.description.choices.length > 0 ? choiceEditor : textEditor
    }
    RedesignButton {
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
        implicitWidth: theme.dp(26); implicitHeight: theme.dp(28); iconSize: theme.dp(18)
        iconName: "history"; text: qsTr("Reset to default")
        onClicked: root.backend.reset(root.optionName)
    }
    Component {
        id: toggleEditor
        Item {
            RedesignButton {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: theme.dp(64); height: theme.dp(30)
                checkable: true
                checked: !!root.currentValue
                text: root.label || root.description.title
                onClicked: root.backend.stage(root.optionName, checked)
                background: Rectangle {
                    radius: theme.dp(4)
                    color: parent.checked ? theme.progress : theme.background
                    border.width: parent.visualFocus ? 1 : 0; border.color: theme.accent
                }
                contentItem: Item {
                    Rectangle {
                        x: parent.parent.checked ? parent.width - width - theme.dp(3) : theme.dp(3)
                        y: theme.dp(3); width: theme.dp(26); height: parent.height - theme.dp(6)
                        radius: theme.dp(3); color: parent.parent.checked ? theme.accent : "#444444"
                    }
                    Text {
                        x: parent.parent.checked ? theme.dp(8) : theme.dp(34)
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.checked ? qsTr("ON") : qsTr("OFF")
                        font.pixelSize: theme.dp(12)
                        color: parent.parent.checked ? theme.accent : theme.foreground
                    }
                }
            }
        }
    }
    Component {
        id: choiceEditor
        C.ComboBox {
            id: choice
            model: root.description.choices
            textRole: "label"; valueRole: "value"
            currentIndex: {
                for (let i = 0; i < count; ++i)
                    if (model[i].value == root.currentValue) return i
                return -1
            }
            font.pixelSize: theme.dp(14)
            palette.text: theme.foreground; palette.buttonText: theme.foreground
            palette.base: theme.field; palette.button: theme.background
            palette.window: theme.panel; palette.highlight: theme.selected; palette.highlightedText: theme.bright
            background: Rectangle { radius: theme.dp(4); color: theme.background; border.color: choice.activeFocus ? theme.accent : theme.border }
            onActivated: root.backend.stage(root.optionName, currentValue)
        }
    }
    Component {
        id: textEditor
        C.TextField {
            id: field
            property bool invalid: false
            text: root.currentValue === undefined ? "" : String(root.currentValue)
            color: invalid ? "#e56b6b" : theme.foreground
            font.pixelSize: theme.dp(14)
            selectByMouse: true
            echoMode: root.description.kind === "password" ? TextInput.Password : TextInput.Normal
            inputMethodHints: root.description.kind === "integer" || root.description.kind === "float" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
            Accessible.name: root.label || root.description.title
            background: Rectangle { radius: theme.dp(4); color: theme.field; border.color: field.invalid ? "#e56b6b" : field.activeFocus ? theme.accent : theme.border }
            onEditingFinished: invalid = !root.backend.stage(root.optionName, text)
            onActiveFocusChanged: if (activeFocus) selectAll()
        }
    }
}
