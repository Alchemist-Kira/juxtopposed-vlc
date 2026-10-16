// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var backend
    property var stereoModel
    property real audioDelaySeconds: 0
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    readonly property var equalizerInfo: { backend.revision; return backend.describe("redesign-equalizer-preset") }
    readonly property var equalizerChoices: equalizerInfo.choices || []
    readonly property string equalizerValue: { backend.revision; return backend.value("redesign-equalizer-preset") || "" }
    readonly property bool twoPass: { backend.revision; return !!backend.value("equalizer-2pass") }
    signal stereoRequested(int index)
    signal delayRequested(real seconds)
    spacing: 0

    RedesignTrackDefaults {
        Layout.fillWidth: true
        backend: root.backend
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
    }
    Text {
        objectName: "stereoModeHeading"
        Layout.fillWidth: true; Layout.minimumHeight: theme.dp(68)
        verticalAlignment: Text.AlignVCenter
        text: qsTr("Stereo Mode"); color: theme.foreground; font.pixelSize: theme.dp(14)
    }
    RedesignModelChoice {
        objectName: "stereoModeSetting"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(4)
        fullWidth: true; label: qsTr("Stereo Mode"); emptyText: qsTr("Automatic")
        choiceModel: root.stereoModel
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        onSelectionRequested: index => root.stereoRequested(index)
    }
    Rectangle {
        Layout.fillWidth: true; Layout.topMargin: theme.dp(22)
        Layout.leftMargin: -theme.dp(24); Layout.rightMargin: -theme.dp(24)
        height: theme.dp(1); color: theme.border
    }
    Text {
        objectName: "audioSynchronizationHeading"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(20); Layout.bottomMargin: theme.dp(18)
        text: qsTr("Synchronization"); color: theme.bright; font.pixelSize: theme.dp(16)
    }
    RedesignSettingSlider {
        objectName: "audioDelaySetting"
        Layout.fillWidth: true
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Audio Track Delay"); suffix: " s"; decimals: 3
        from: -10; to: 10; inputFrom: -2147483.648; inputTo: 2147483.647; stepSize: 0.05
        ticks: [-10, 0, 10]; tickSuffix: " s"; sliderTopMargin: 10
        resetValue: 0; currentValue: root.audioDelaySeconds
        onMoved: value => root.delayRequested(value)
    }
    Rectangle {
        Layout.fillWidth: true; Layout.topMargin: theme.dp(24)
        Layout.leftMargin: -theme.dp(24); Layout.rightMargin: -theme.dp(24)
        height: theme.dp(1); color: theme.border
    }
    Text {
        objectName: "audioFiltersHeading"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(20); Layout.bottomMargin: theme.dp(8)
        text: qsTr("Filters"); color: theme.bright; font.pixelSize: theme.dp(16)
    }
    Text {
        Layout.fillWidth: true; Layout.minimumHeight: theme.dp(36)
        visible: root.equalizerInfo.kind !== undefined
        text: qsTr("Equalizer"); color: theme.foreground; font.pixelSize: theme.dp(14)
        verticalAlignment: Text.AlignVCenter
    }
    RedesignComboBox {
        objectName: "inlineEqualizerPreset"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(11)
        implicitHeight: theme.dp(46); choiceHeight: 46
        visible: root.equalizerInfo.kind !== undefined
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        model: root.equalizerChoices; textRole: "label"; valueRole: "value"
        showCurvePreviews: true
        currentIndex: root.equalizerChoices.findIndex(choice => choice.value === root.equalizerValue)
        Accessible.name: qsTr("Equalizer")
        onAboutToOpen: root.backend.refresh()
        onActivated: root.backend.stage("redesign-equalizer-preset", currentValue)
    }
    RedesignEqualizer {
        objectName: "inlineEqualizer"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(10)
        visible: root.equalizerInfo.kind !== undefined
        compact: true; backend: root.backend
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
    }
    RedesignSwitchRow {
        objectName: "inlineEqualizerTwoPass"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(8)
        visible: root.equalizerInfo.kind !== undefined
        label: qsTr("2 Pass"); checked: root.twoPass
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        onToggled: checked => root.backend.stage("equalizer-2pass", checked)
    }
    RedesignPreferenceRow {
        objectName: "inlineSpatializerSetting"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(16)
        backend: root.backend; optionName: "filter:audio-filter:spatializer"; label: qsTr("Spatializer")
        presentation: ({compact: true, spatializer: true})
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
    }

}
