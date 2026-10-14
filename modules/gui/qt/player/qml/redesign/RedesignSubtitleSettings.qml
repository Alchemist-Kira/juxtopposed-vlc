// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var backend
    property real subtitleDelaySeconds: 0
    property real subtitleFPS: 0
    property int liveSizeMode: -1
    property var liveTextScale: undefined
    property var livePixelSize: undefined
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    readonly property bool pixels: { backend.revision; return (liveSizeMode >= 0 ? liveSizeMode : Number(backend.value("sub-text-size-mode"))) === 1 }
    readonly property bool manualStyle: { backend.revision; return !backend.value("sub-text-use-embedded-style") }
    readonly property real fontSize: { backend.revision; const live = root.pixels ? livePixelSize : liveTextScale; return live === undefined ? Number(backend.value(root.pixels ? "sub-text-size-pixels" : "sub-text-scale")) : Number(live) }
    signal delayRequested(real seconds)
    signal fpsRequested(real fps)
    spacing: 0

    // Keep the normal values near the middle while retaining the complete
    // native range. This also gives the left/right keys a precise native step.
    function sliderPosition(value, minimum, normal, maximum, middle) {
        return value <= normal ? middle * (value - minimum) / (normal - minimum)
            : middle + (1 - middle) * (value - normal) / (maximum - normal)
    }
    function sliderValue(position, minimum, normal, maximum, middle) {
        return position <= middle ? minimum + position / middle * (normal - minimum)
            : normal + (position - middle) / (1 - middle) * (maximum - normal)
    }

    RedesignTrackDefaults { Layout.fillWidth: true; subtitles: true; backend: root.backend; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    Rectangle { Layout.fillWidth: true; Layout.leftMargin: -theme.dp(24); Layout.rightMargin: -theme.dp(20); Layout.topMargin: theme.dp(4); height: theme.dp(1); color: theme.border }
    Text { objectName: "subtitleSynchronizationHeading"; Layout.topMargin: theme.dp(20); Layout.bottomMargin: theme.dp(20); text: qsTr("Synchronization"); color: theme.bright; font.pixelSize: theme.dp(16) }
    RedesignSettingSlider {
        objectName: "subtitleDelaySetting"
        Layout.fillWidth: true
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Subtitle Track Delay"); suffix: " s"; decimals: 3
        from: -10; to: 10; inputFrom: -2147483.648; inputTo: 2147483.647; stepSize: 0.05
        ticks: [-10, 0, 10]; tickSuffix: " s"; positiveTickSign: true; sliderTopMargin: 10; sliderLeftMargin: -4
        resetValue: 0; currentValue: root.subtitleDelaySeconds
        onMoved: value => root.delayRequested(value)
    }
    RedesignSettingSlider {
        objectName: "subtitleFPSControl"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(16)
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Subtitle Speed"); suffix: " fps"; decimals: 3
        from: 0; to: 60; inputTo: 2147483.647; stepSize: 0.001
        resetValue: 0; minimumValueText: qsTr("Automatic")
        scaleLabelsVisible: false; sliderTopMargin: 10; sliderLeftMargin: -4
        currentValue: root.subtitleFPS
        onMoved: value => root.fpsRequested(value)
    }
    RedesignSettingSlider {
        objectName: "subtitleDurationSetting"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(14)
        visible: root.backend.describe("redesign-subtitle-duration").kind !== undefined
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Subtitle Duration Factor"); decimals: 3
        from: 0; to: 20; stepSize: 0.001; resetValue: 0
        scaleLabelsVisible: false; sliderTopMargin: 10; sliderLeftMargin: -4
        currentValue: { root.backend.revision; return Number(root.backend.value("redesign-subtitle-duration")) }
        onMoved: value => root.backend.stage("redesign-subtitle-duration", value)
    }
    Rectangle { Layout.fillWidth: true; Layout.leftMargin: -theme.dp(24); Layout.rightMargin: -theme.dp(20); Layout.topMargin: theme.dp(18); height: theme.dp(1); color: theme.border }
    Text { objectName: "subtitleAppearanceHeading"; Layout.topMargin: theme.dp(20); Layout.bottomMargin: theme.dp(8); text: qsTr("Appearance"); color: theme.bright; font.pixelSize: theme.dp(16) }
    Repeater {
        model: [
            {name: "sub-text-use-embedded-style", label: qsTr("Embedded Sub Format"), manual: false},
            {name: "freetype-font", label: qsTr("Subtitle Font"), manual: true},
            {name: "freetype-color", label: qsTr("Text Color"), manual: true},
            {name: "freetype-outline-color", label: qsTr("Outline Color"), manual: true},
            {name: "sub-margin", label: qsTr("Subtitle Offset"), manual: false, suffix: " px"}
        ]
        RedesignPreferenceRow {
            required property var modelData
            objectName: "subtitleAppearance_" + modelData.name
            Layout.fillWidth: true
            backend: root.backend; optionName: modelData.name; label: modelData.label
            presentation: ({compact: true, suffix: modelData.suffix || "", enabledWhen: modelData.manual ? "redesign-subtitle-manual-style" : ""})
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        }
    }
    RowLayout {
        objectName: "subtitleSizeModeSetting"
        Layout.fillWidth: true; Layout.preferredHeight: theme.dp(60)
        Text { Layout.fillWidth: true; text: qsTr("Size Values"); color: theme.foreground; font.pixelSize: theme.dp(14) }
        Rectangle {
            Layout.preferredWidth: theme.dp(180); Layout.preferredHeight: theme.dp(38)
            radius: theme.dp(4); color: theme.field; border.color: theme.border
            RowLayout {
                anchors.fill: parent; anchors.margins: theme.dp(2); spacing: theme.dp(2)
                Repeater {
                    model: [qsTr("Relative"), qsTr("Pixels")]
                    RedesignButton {
                        required property string modelData
                        required property int index
                        objectName: index === 0 ? "subtitleSizeRelative" : "subtitleSizePixels"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        caption: modelData; text: modelData
                        selected: root.pixels === (index === 1)
                        background: Rectangle { radius: theme.dp(3); color: parent.selected ? theme.progress : parent.hovered ? theme.hover : "transparent"; border.width: parent.visualFocus ? 1 : 0; border.color: theme.accent }
                        onClicked: root.backend.stage("sub-text-size-mode", index)
                    }
                }
            }
        }
    }
    RedesignSettingSlider {
        id: fontSizeSlider
        objectName: "subtitleFontSizeSetting"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(22)
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Font Size"); displayValueAsText: true
        valueLabel: root.pixels ? Math.round(root.fontSize) + " px" : root.fontSize === 100 ? qsTr("Auto") : Math.round(root.fontSize) + " %"
        from: root.pixels ? 1 : 10; to: 500; stepSize: 1; scaleLabelsVisible: false; sliderTopMargin: 6; sliderLeftMargin: -4
        currentValue: root.fontSize
        readonly property real normal: root.pixels ? 30 : 100
        valueToPosition: value => root.sliderPosition(value, from, normal, to, 0.6)
        positionToValue: position => Math.round(root.sliderValue(position, from, normal, to, 0.6))
        ticks: [0, .2, .4, .6, .8, 1].map(position => root.sliderValue(position, from, normal, to, 0.6))
        onMoved: value => root.backend.stage(root.pixels ? "sub-text-size-pixels" : "sub-text-scale", value)
    }
    RedesignSettingSlider {
        objectName: "subtitleOutlineThicknessSetting"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(36)
        enabled: root.manualStyle; opacity: enabled ? 1 : .5
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Outline Thickness"); displayValueAsText: true
        valueLabel: currentValue === 0 ? qsTr("None") : currentValue === 1 ? qsTr("Thin") : currentValue === 4 ? qsTr("Normal") : currentValue === 8 ? qsTr("Thick") : Math.round(currentValue) + " %"
        from: 0; to: 50; stepSize: 1; scaleLabelsVisible: false; sliderTopMargin: 6; sliderLeftMargin: -4
        currentValue: { root.backend.revision; return Number(root.backend.value("freetype-outline-thickness")) }
        valueToPosition: value => root.sliderPosition(value, 0, 4, 50, 0.65)
        positionToValue: position => Math.round(root.sliderValue(position, 0, 4, 50, 0.65))
        ticks: [0, .2, .4, .6, .8, 1].map(position => root.sliderValue(position, 0, 4, 50, 0.65))
        onMoved: value => root.backend.stage("freetype-outline-thickness", value)
    }
    RedesignSettingSlider {
        objectName: "subtitleBackgroundOpacitySetting"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(36)
        enabled: root.manualStyle; opacity: enabled ? 1 : .5
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Background Opacity"); displayValueAsText: true
        valueLabel: Math.round(currentValue) + " %"
        from: 0; to: 100; stepSize: 1; ticks: [0, 20, 40, 60, 80, 100]
        scaleLabelsVisible: false; sliderTopMargin: 6; sliderLeftMargin: -4
        currentValue: { root.backend.revision; return Math.round(Number(root.backend.value("freetype-background-opacity")) * 100 / 255) }
        onMoved: value => root.backend.stage("freetype-background-opacity", Math.round(value * 255 / 100))
    }
    Item { Layout.fillWidth: true; height: theme.dp(10) }
}
