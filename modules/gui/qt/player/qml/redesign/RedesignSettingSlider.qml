// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C
import QtQuick.Templates as T

ColumnLayout {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property string label
    property string suffix
    property int decimals: 0
    property real currentValue: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property real resetValue: 1
    property string minimumValueText
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal moved(real value)
    spacing: theme.dp(8)
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: root.label; color: theme.foreground; font.pixelSize: theme.dp(14); wrapMode: Text.WordWrap }
        T.SpinBox {
            id: valueField
            objectName: "settingValueField"
            property real factor: Math.pow(10, root.decimals)
            Layout.preferredWidth: theme.dp(138)
            implicitHeight: theme.dp(34)
            leftPadding: theme.dp(14); rightPadding: theme.dp(10)
            font.pixelSize: theme.dp(14)
            editable: true
            from: Math.round(root.from * factor); to: Math.round(root.to * factor)
            stepSize: Math.max(1, Math.round(root.stepSize * factor))
            value: Math.round(root.currentValue * factor)
            textFromValue: (value, locale) => root.minimumValueText && value === from ? root.minimumValueText
                : Number(value / factor).toLocaleString(locale, 'f', root.decimals) + root.suffix
            valueFromText: (text, locale) => {
                let input = text.trim()
                if (root.minimumValueText && input.toLocaleLowerCase() === root.minimumValueText.toLocaleLowerCase()) return from
                if (root.suffix && input.endsWith(root.suffix)) input = input.slice(0, -root.suffix.length).trim()
                let number = NaN
                try { if (input.length) number = Number.fromLocaleString(locale, input) }
                catch (error) { return value }
                const scaled = Math.round(number * factor)
                return Number.isFinite(number) && number >= root.from && number <= root.to ? scaled : value
            }
            // The displayed value can contain decimals, a unit or Automatic.
            // The integer validator of the standard SpinBox rejects those.
            contentItem: TextInput {
                text: valueField.displayText
                font: valueField.font; color: theme.foreground
                selectionColor: theme.accent; selectedTextColor: theme.background
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true; clip: true
                onActiveFocusChanged: if (activeFocus) selectAll()
            }
            background: Rectangle {
                radius: theme.dp(4); color: theme.field
                border.color: valueField.activeFocus ? theme.accent : theme.background
            }
            Accessible.name: root.label
            onValueModified: root.moved(value / factor)
        }
    }
    C.Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: theme.dp(24)
        from: root.from; to: root.to; stepSize: root.stepSize
        Binding on value { when: !slider.pressed; value: root.currentValue }
        onMoved: root.moved(value)
        Accessible.name: root.label
        background: Rectangle {
            x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth; height: theme.dp(14); radius: theme.dp(5); color: theme.field
            Rectangle { width: slider.position * parent.width; height: parent.height; radius: parent.radius; color: theme.progress }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: theme.dp(8); height: theme.dp(24); radius: theme.dp(4); color: theme.accent
            border.width: slider.visualFocus ? 1 : 0; border.color: theme.bright
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { text: root.from + root.suffix; color: theme.foreground; font.pixelSize: theme.dp(11) }
        Item { Layout.fillWidth: true }
        RedesignButton { objectName: "settingResetButton"; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Reset"); text: qsTr("Reset %1").arg(root.label); implicitHeight: theme.dp(24); onClicked: root.moved(root.resetValue) }
        Item { Layout.fillWidth: true }
        Text { text: root.to + root.suffix; color: theme.foreground; font.pixelSize: theme.dp(11) }
    }
}
