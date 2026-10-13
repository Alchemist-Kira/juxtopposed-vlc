// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C

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
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal moved(real value)
    spacing: theme.dp(8)
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: root.label; color: theme.foreground; font.pixelSize: theme.dp(14); wrapMode: Text.WordWrap }
        C.SpinBox {
            id: valueField
            property real factor: Math.pow(10, root.decimals)
            Layout.preferredWidth: theme.dp(115)
            editable: true
            from: Math.round(root.from * factor); to: Math.round(root.to * factor)
            stepSize: Math.max(1, Math.round(root.stepSize * factor))
            value: Math.round(root.currentValue * factor)
            textFromValue: (value, locale) => Number(value / factor).toLocaleString(locale, 'f', root.decimals) + root.suffix
            valueFromText: (text, locale) => Math.round(Number.fromLocaleString(locale, text.replace(root.suffix, "").trim()) * factor)
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
        RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Reset"); text: qsTr("Reset %1").arg(root.label); implicitHeight: theme.dp(24); onClicked: root.moved(root.from < 0 ? 0 : 1) }
        Item { Layout.fillWidth: true }
        Text { text: root.to + root.suffix; color: theme.foreground; font.pixelSize: theme.dp(11) }
    }
}
