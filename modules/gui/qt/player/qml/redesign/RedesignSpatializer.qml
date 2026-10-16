// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var backend
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    property bool expanded: false
    readonly property bool effectEnabled: { backend.revision; return !!backend.value("filter:audio-filter:spatializer") }
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    spacing: 0
    RedesignButton {
        id: expander
        objectName: "spatializerExpander"
        Layout.fillWidth: true; Layout.preferredHeight: theme.dp(48)
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        text: root.expanded ? qsTr("Collapse Settings") : qsTr("Expand Settings")
        background: Rectangle { radius: theme.dp(4); color: parent.hovered ? theme.hover : root.expanded ? root.lightTheme ? theme.background : "#191919" : theme.field }
        contentItem: RowLayout {
            spacing: theme.dp(10)
            Text { Layout.fillWidth: true; text: expander.text; color: theme.foreground; font.pixelSize: theme.dp(14) }
            RedesignIcon { name: root.expanded ? "chevron-down" : "chevron-right"; color: theme.foreground; Layout.preferredWidth: theme.dp(20); Layout.preferredHeight: theme.dp(20) }
        }
        leftPadding: theme.dp(16); rightPadding: theme.dp(16)
        onClicked: root.expanded = !root.expanded
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: controls.implicitHeight + theme.dp(31)
        visible: root.expanded
        color: root.lightTheme ? theme.background : "#191919"
        ColumnLayout {
            id: controls
            anchors.top: parent.top; anchors.topMargin: theme.dp(12)
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: theme.dp(16)
            spacing: theme.dp(21)
            enabled: root.effectEnabled
            opacity: enabled ? 1 : 0.7
            Repeater {
                model: [{name: "spatializer-roomsize", label: qsTr("Size")}, {name: "spatializer-width", label: qsTr("Width")},
                        {name: "spatializer-wet", label: qsTr("Wet")}, {name: "spatializer-dry", label: qsTr("Dry")}, {name: "spatializer-damp", label: qsTr("Damp")}]
                RedesignSettingSlider {
                    required property var modelData
                    readonly property var description: root.backend.describe(modelData.name)
                    objectName: modelData.name
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    label: modelData.label
                    from: Number(description.minimum || 0) * 10; to: Number(description.maximum || 1) * 10
                    currentValue: { root.backend.revision; return Number(root.backend.value(modelData.name)) * 10 }
                    decimals: 1; stepSize: 0.1; displayValueAsText: true
                    trackHeight: 16; trackRadius: 6; trackInset: 2
                    valueLabel: Number(currentValue).toLocaleString(Qt.locale(), 'f', 1)
                    ticks: [1, 2, 3, 4, 5, 6, 7, 8, 9]; scaleLabelsVisible: false; sliderTopMargin: 6
                    onMoved: value => root.backend.stage(modelData.name, value / 10)
                }
            }
        }
    }
}
