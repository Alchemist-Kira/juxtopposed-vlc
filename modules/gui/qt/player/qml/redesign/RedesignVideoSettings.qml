// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import QtQml.Models

ColumnLayout {
    id: root
    required property var backend
    property var rendererModel
    property var videoTracksModel
    property var deinterlaceModel
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    property int liveRevision: 0
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    signal trackRequested(int index)
    signal deinterlaceRequested(int index)
    signal moreFiltersRequested()
    spacing: 0

    function current(name) { backend.revision; liveRevision; return backend.videoValue(name) }
    function enabledFilter(name, chain = "video-filter") { return String(current(chain) || "").split(":").includes(name) }
    function effect(name, enabled, chain = "video-filter") { return backend.stage("filter:" + chain + ":" + name, enabled) }
    function options(name, rows) {
        const result = rows.slice()
        const value = current(name)
        if (value !== undefined && !result.some(row => row.value === value))
            result.push({label: name === "crop" && String(value).includes("+") ? qsTr("Custom") : String(value), value: value})
        return result
    }
    readonly property string videoTransform: enabledFilter("transform") ? String(current("transform-type")) : ""
    readonly property int flip: videoTransform === "hflip" || videoTransform === "transpose" ? 1 : videoTransform === "vflip" || videoTransform === "antitranspose" ? 2 : 0
    readonly property real rotationDegrees: (enabledFilter("rotate") ? Number(current("rotate-angle")) : 0)
        + ({"90": 90, "180": 180, "270": 270, "transpose": 90, "antitranspose": 90}[videoTransform] || 0)
    function setFlip(index) {
        const angle = rotationDegrees
        const legacy = videoTransform && videoTransform !== "hflip" && videoTransform !== "vflip"
        if (backend.stage("transform-type", index === 2 ? "vflip" : "hflip")) {
            effect("transform", index !== 0)
            if (legacy) setRotation(angle)
        }
    }
    function setRotation(angle) {
        const flipIndex = flip
        if (videoTransform && videoTransform !== "hflip" && videoTransform !== "vflip") {
            backend.stage("transform-type", flipIndex === 2 ? "vflip" : "hflip")
            effect("transform", flipIndex !== 0)
        }
        if (backend.stage("rotate-angle", angle)) effect("rotate", angle !== 0)
    }
    function borders() {
        const parts = String(current("crop") || "").split("+")
        return parts.length === 4 && parts.every(value => /^\d+$/.test(value)) ? parts.map(Number) : [0, 0, 0, 0]
    }
    function setBorder(index, value) {
        if (!Number.isInteger(value) || value < 0 || value > 2147483647) return false
        const values = borders()
        values[index] = value
        if (index % 2 === 0 && cropSection.contentItem.linkHorizontal) values[2 - index] = value
        if (index % 2 === 1 && cropSection.contentItem.linkVertical) values[4 - index] = value
        return backend.stage("crop", values.join("+"))
    }
    Timer { interval: 400; running: root.visible; repeat: true; onTriggered: root.liveRevision++ }

    component Choice: RowLayout {
        property string label
        property string optionName
        property var choices
        property string help
        property string emptyText
        Layout.fillWidth: true; Layout.minimumHeight: theme.dp(68)
        Text { Layout.fillWidth: true; text: parent.label; color: theme.foreground; font.pixelSize: theme.dp(14); wrapMode: Text.WordWrap }
        RedesignComboBox {
            objectName: parent.optionName + "Choice"
            Layout.preferredWidth: Math.min(theme.dp(217), root.width * .61); Layout.minimumWidth: 0
            implicitHeight: theme.dp(46)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            model: parent.choices; textRole: "label"; valueRole: "value"
            currentIndex: model.findIndex(row => row.value === root.current(parent.optionName))
            displayText: currentIndex < 0 ? parent.emptyText : currentText
            Accessible.name: parent.label
            onActivated: {
                if (parent.optionName === "zoom") root.backend.stage("fit", 0)
                root.backend.stage(parent.optionName, currentValue)
            }
            C.ToolTip.text: parent.help
            C.ToolTip.visible: hovered && C.ToolTip.text.length > 0
            C.ToolTip.delay: 650
        }
    }
    component FilterSlider: RedesignSettingSlider {
        required property string optionName
        Layout.fillWidth: true
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        visible: root.backend.describe(optionName).kind !== undefined
        currentValue: Number(root.current(optionName))
        valueFieldVisible: false; scaleLabelsVisible: false; sliderTopMargin: 8
        onMoved: value => root.backend.stage(optionName, value)
    }
    component FilterSwitch: RedesignSwitchRow {
        required property string filterName
        Layout.fillWidth: true
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        visible: root.backend.describe("filter:video-filter:" + filterName).kind !== undefined
        checked: root.enabledFilter(filterName)
        onToggled: checked => root.effect(filterName, checked)
    }

    Text { Layout.topMargin: theme.dp(12); Layout.bottomMargin: theme.dp(26); text: qsTr("Defaults"); color: theme.foreground; font.pixelSize: theme.dp(16) }
    Text { Layout.bottomMargin: theme.dp(18); text: qsTr("Flip"); color: theme.foreground; font.pixelSize: theme.dp(14) }
    RowLayout {
        Layout.fillWidth: true; Layout.preferredHeight: theme.dp(44); spacing: theme.dp(2)
        Repeater {
            model: [qsTr("None"), qsTr("Horizontal"), qsTr("Vertical")]
            RedesignButton {
                required property int index
                required property string modelData
                objectName: "videoFlip_" + index
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                caption: modelData; text: qsTr("Flip: %1").arg(modelData); selected: root.flip === index
                background: Rectangle { radius: theme.dp(4); color: parent.selected ? theme.progress : parent.hovered ? theme.hover : theme.background; border.color: parent.visualFocus ? theme.accent : theme.field }
                onClicked: root.setFlip(index)
            }
        }
    }
    RedesignSettingSlider {
        objectName: "videoRotation"
        Layout.fillWidth: true; Layout.topMargin: theme.dp(28); Layout.bottomMargin: theme.dp(16)
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        label: qsTr("Rotate"); suffix: " deg"; decimals: 1; trimTrailingZeros: true
        from: -360; to: 360; stepSize: 1; currentValue: root.rotationDegrees
        sliderVisible: false
        onMoved: value => root.setRotation(value)
    }
    Choice { label: qsTr("Zoom"); optionName: "zoom"; choices: root.options(optionName, [{label: qsTr("1:4 Quarter"), value: .25}, {label: qsTr("1:2 Half"), value: .5}, {label: qsTr("1:1 Original"), value: 1}, {label: qsTr("2:1 Double"), value: 2}]) }
    Choice {
        label: qsTr("HDR"); optionName: "d3d11-hdr-mode"
        enabled: root.backend.describe(optionName).kind !== undefined
        opacity: enabled ? 1 : .5
        choices: [{label: qsTr("Auto"), value: "auto"}, {label: qsTr("Off"), value: "never"}, {label: qsTr("On"), value: "always"}, {label: qsTr("Generate HDR from SDR"), value: "generate"}]
        help: enabled ? qsTr("Use this mode when the video starts.") : qsTr("This video output does not support this setting.")
        emptyText: qsTr("Auto")
    }
    Choice {
        label: qsTr("Resolution"); optionName: "preferred-resolution"
        choices: root.backend.describe(optionName).choices || []
        help: qsTr("Set the preferred quality for the next video.")
    }
    Choice { label: qsTr("Aspect Ratio"); optionName: "aspect-ratio"; choices: root.options(optionName, ["", "1:1", "4:3", "5:4", "16:9", "16:10", "2.21:1", "2.35:1", "2.39:1"].map(value => ({label: value || qsTr("Default"), value: value}))) }
    Choice { label: qsTr("Crop"); optionName: "crop"; choices: root.options(optionName, ["", "16:10", "16:9", "1.85:1", "2.21:1", "2.35:1", "2.39:1", "5:3", "4:3", "5:4", "1:1"].map(value => ({label: value || qsTr("Default"), value: value}))) }
    RowLayout {
        Layout.fillWidth: true; Layout.minimumHeight: theme.dp(68)
        Text { Layout.fillWidth: true; text: qsTr("Render"); color: theme.foreground; font.pixelSize: theme.dp(14) }
        Instantiator {
            id: renderers
            model: root.rendererModel
            delegate: QtObject { required property string name; required property bool selected }
        }
        RedesignComboBox {
            objectName: "videoRendererChoice"
            Layout.preferredWidth: Math.min(theme.dp(217), root.width * .61); Layout.minimumWidth: 0; implicitHeight: theme.dp(46)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            model: {
                const rows = [qsTr("Local")]
                for (let i = 0; i < renderers.count; ++i) rows.push(renderers.objectAt(i).name)
                return rows
            }
            currentIndex: {
                if (!root.rendererModel || !root.rendererModel.useRenderer) return 0
                for (let i = 0; i < renderers.count; ++i) if (renderers.objectAt(i).selected) return i + 1
                return -1
            }
            Accessible.name: qsTr("Render")
            onAboutToOpen: if (root.rendererModel) root.rendererModel.StartScan()
            onActivated: index => {
                if (!root.rendererModel) return
                if (index === 0) root.rendererModel.disableRenderer()
                else root.rendererModel.setData(root.rendererModel.index(index - 1, 0), true, Qt.CheckStateRole)
            }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.leftMargin: -theme.dp(24); Layout.rightMargin: -theme.dp(20); Layout.topMargin: theme.dp(12); height: theme.dp(1); color: theme.border }
    Text { Layout.topMargin: theme.dp(20); text: qsTr("Filters"); color: theme.foreground; font.pixelSize: theme.dp(16) }
    RedesignFilterSection {
        objectName: "videoEssentialSection"
        Layout.fillWidth: true; label: qsTr("Essential")
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        settings: ColumnLayout {
            spacing: theme.dp(18)
            FilterSlider { objectName: "videoHue"; label: qsTr("Hue"); optionName: "hue"; from: -180; to: 180; decimals: 1; stepSize: 1 }
            FilterSlider { objectName: "videoBrightness"; label: qsTr("Brightness"); optionName: "brightness"; from: 0; to: 2; decimals: 2; stepSize: .01 }
            FilterSlider { objectName: "videoContrast"; label: qsTr("Contrast"); optionName: "contrast"; from: 0; to: 2; decimals: 2; stepSize: .01 }
            FilterSlider { objectName: "videoSaturation"; label: qsTr("Saturation"); optionName: "saturation"; from: 0; to: 3; decimals: 2; stepSize: .01; ticks: [0, 1, 2, 3] }
            FilterSlider { objectName: "videoGamma"; label: qsTr("Gamma"); optionName: "gamma"; from: .01; to: 10; decimals: 2; stepSize: .01; ticks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }
            FilterSlider { objectName: "videoSharpen"; label: qsTr("Sharpen Sigma"); optionName: "sharpen-sigma"; from: 0; to: 2; decimals: 2; stepSize: .01; ticks: [0, .5, 1, 1.5, 2] }
            FilterSlider { objectName: "videoBanding"; label: qsTr("Banding Removal Radius"); optionName: "gradfun-radius"; from: 4; to: 32; stepSize: 1; ticks: [4, 8, 12, 16, 20, 24, 28, 32] }
            FilterSlider { objectName: "videoGrain"; label: qsTr("Film Grain Variance"); optionName: "grain-variance"; from: 0; to: 10; decimals: 2; stepSize: .01; ticks: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }
        }
    }
    RedesignFilterSection {
        id: cropSection
        objectName: "videoCropSection"
        Layout.fillWidth: true; label: qsTr("Crop")
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        settings: ColumnLayout {
            id: cropSettings
            property bool linkVertical: false
            property bool linkHorizontal: false
            spacing: theme.dp(14)
            Repeater {
                model: [[{label: qsTr("Top"), side: 1}, {label: qsTr("Bottom"), side: 3}], [{label: qsTr("Left"), side: 0}, {label: qsTr("Right"), side: 2}]]
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; spacing: theme.dp(8)
                    Repeater {
                        model: parent.modelData
                        C.TextField {
                            required property var modelData
                            objectName: "videoCropBorder_" + modelData.side
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            implicitHeight: theme.dp(34); leftPadding: theme.dp(12); rightPadding: theme.dp(8)
                            color: theme.foreground; font.pixelSize: theme.dp(14)
                            Binding on text { restoreMode: Binding.RestoreNone; when: !activeFocus; value: root.borders()[modelData.side] + " px" }
                            horizontalAlignment: TextInput.AlignRight
                            leftInset: 0; rightInset: 0
                            background: Rectangle { radius: theme.dp(4); color: theme.field; border.color: parent.activeFocus ? theme.accent : "transparent" }
                            Text { anchors.left: parent.left; anchors.leftMargin: theme.dp(12); anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.label; color: theme.foreground; font: parent.font }
                            onActiveFocusChanged: if (activeFocus) selectAll()
                            onEditingFinished: {
                                const input = text.trim().replace(/\s*px$/, "")
                                if (/^\d+$/.test(input)) root.setBorder(modelData.side, Number(input))
                                text = root.borders()[modelData.side] + " px"
                            }
                            Accessible.name: qsTr("Crop %1").arg(modelData.label)
                        }
                    }
                    RedesignButton {
                        objectName: "videoCropLink_" + index
                        Layout.preferredWidth: theme.dp(30); Layout.preferredHeight: theme.dp(34)
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                        text: index === 0 ? qsTr("Link top and bottom") : qsTr("Link left and right")
                        selected: index === 0 ? cropSettings.linkVertical : cropSettings.linkHorizontal
                        contentItem: RedesignSvg {
                            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                            svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M9 7H7a5 5 0 0 0 0 10h2m6-10h2a5 5 0 0 1 0 10h-2' + (parent.selected ? 'M8 12h8' : '') + '" fill="none" stroke="' + (parent.selected ? theme.accent : theme.foreground) + '" stroke-width="1.5" stroke-linecap="round"/></svg>'
                        }
                        onClicked: { if (index === 0) cropSettings.linkVertical = !cropSettings.linkVertical; else cropSettings.linkHorizontal = !cropSettings.linkHorizontal }
                    }
                }
            }
        }
    }
    RedesignFilterSection {
        objectName: "videoColorsSection"
        Layout.fillWidth: true; label: qsTr("Colors"); contentTopMargin: -3
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        settings: ColumnLayout {
            spacing: 0
            Repeater {
                model: [{label: qsTr("Color Extraction"), name: "extract", option: "extract-component"}, {label: qsTr("Color Threshold"), name: "colorthres", option: "colorthres-color"}]
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; Layout.bottomMargin: modelData.name === "extract" ? theme.dp(20) : theme.dp(12); spacing: theme.dp(12)
                    GridLayout {
                        columns: root.width < theme.dp(320) ? 2 : 3
                        columnSpacing: theme.dp(10); rowSpacing: theme.dp(10)
                        Layout.fillWidth: true; Layout.minimumHeight: theme.dp(52)
                        Text { Layout.columnSpan: parent.columns === 2 ? 2 : 1; Layout.fillWidth: true; text: modelData.label; color: theme.foreground; font.pixelSize: theme.dp(14); wrapMode: Text.WordWrap }
                        C.TextField {
                            id: colorField
                            objectName: "videoColor_" + modelData.name
                            Layout.fillWidth: parent.columns === 2; Layout.minimumWidth: 0; Layout.preferredWidth: theme.dp(112); implicitHeight: theme.dp(34)
                            leftPadding: theme.dp(12); rightPadding: theme.dp(32)
                            Binding on text { restoreMode: Binding.RestoreNone; when: !colorField.activeFocus; value: "#" + Number(root.current(modelData.option)).toString(16).padStart(6, "0").toUpperCase() }
                            color: theme.foreground; font.pixelSize: theme.dp(14)
                            background: Rectangle { radius: theme.dp(4); color: theme.field; border.color: parent.activeFocus ? theme.accent : "transparent" }
                            onEditingFinished: {
                                const input = text.trim().replace(/^#/, "")
                                if (/^[0-9a-fA-F]{6}$/.test(input)) root.backend.stage(modelData.option, parseInt(input, 16))
                                text = "#" + Number(root.current(modelData.option)).toString(16).padStart(6, "0").toUpperCase()
                            }
                            Accessible.name: modelData.label
                            RedesignButton {
                                anchors.right: parent.right; anchors.rightMargin: theme.dp(5); anchors.verticalCenter: parent.verticalCenter
                                width: theme.dp(22); height: width
                                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                                text: qsTr("Choose %1 color").arg(modelData.label)
                                background: Rectangle { radius: theme.dp(2); color: colorField.text; border.color: parent.visualFocus ? theme.accent : theme.border }
                                onClicked: { const color = root.backend.chooseColor(colorField.text); if (color) root.backend.stage(modelData.option, parseInt(color.replace(/^#/, ""), 16)) }
                            }
                        }
                        FilterSwitch { Layout.fillWidth: false; Layout.preferredWidth: theme.dp(64); label: ""; accessibleName: modelData.label; filterName: modelData.name }
                    }
                    FilterSlider { Layout.topMargin: -theme.dp(8); Layout.bottomMargin: theme.dp(8); visible: modelData.name === "colorthres"; label: qsTr("Saturation"); optionName: "colorthres-saturationthres"; from: 0; to: 100; stepSize: 1 }
                    FilterSlider { Layout.bottomMargin: theme.dp(16); visible: modelData.name === "colorthres"; label: qsTr("Similarity"); optionName: "colorthres-similaritythres"; from: 0; to: 100; stepSize: 1 }
                }
            }
            FilterSwitch { label: qsTr("Negate Colors"); filterName: "invert" }
            FilterSwitch { label: qsTr("Posterize"); filterName: "posterize" }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: theme.dp(6); height: theme.dp(1); color: theme.border }
            FilterSwitch { label: qsTr("Gradient"); filterName: "gradient" }
            RedesignComboBox {
                objectName: "videoGradientMode"
                Layout.fillWidth: true; Layout.topMargin: theme.dp(7); implicitHeight: theme.dp(46)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                model: root.backend.describe("gradient-mode").choices || []; textRole: "label"; valueRole: "value"
                currentIndex: model.findIndex(row => row.value === root.current("gradient-mode"))
                Accessible.name: qsTr("Gradient mode")
                onActivated: root.backend.stage("gradient-mode", currentValue)
            }
            Repeater {
                model: [{label: qsTr("Color"), option: "gradient-color"}, {label: qsTr("Cartoon"), option: "gradient-cartoon"}]
                RedesignSwitchRow {
                    required property var modelData
                    Layout.fillWidth: true
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                    label: modelData.label; checked: !!root.current(modelData.option)
                    onToggled: checked => root.backend.stage(modelData.option, checked)
                }
            }
            FilterSlider { objectName: "videoSepia"; Layout.topMargin: theme.dp(20); label: qsTr("Sepia Intensity"); optionName: "sepia-intensity"; from: 0; to: 255; stepSize: 1; ticks: [0, 85, 170, 255] }
        }
    }
    RedesignFilterSection {
        objectName: "videoGeometrySection"
        Layout.fillWidth: true; label: qsTr("Geometry")
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        settings: ColumnLayout {
            FilterSwitch { label: qsTr("Interactive Zoom"); filterName: "magnify" }
            FilterSwitch { label: qsTr("Puzzle"); filterName: "puzzle" }
        }
    }
    RedesignFilterSection {
        objectName: "videoOverlaySection"
        Layout.fillWidth: true; label: qsTr("Overlay")
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        settings: RedesignButton {
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            caption: qsTr("Text and Image Overlays"); text: caption
            onClicked: root.moreFiltersRequested()
        }
    }
    RedesignFilterSection {
        objectName: "videoAdvancedSection"
        Layout.fillWidth: true; label: qsTr("Advanced")
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
        settings: ColumnLayout {
            RedesignModelChoice { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; label: qsTr("Video Track"); choiceModel: root.videoTracksModel; onSelectionRequested: index => root.trackRequested(index) }
            RedesignModelChoice { Layout.fillWidth: true; scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; label: qsTr("Deinterlace"); choiceModel: root.deinterlaceModel; onSelectionRequested: index => root.deinterlaceRequested(index) }
            FilterSwitch { label: qsTr("Motion Detect"); filterName: "motiondetect" }
            FilterSwitch { label: qsTr("Motion Blur"); filterName: "motionblur" }
            FilterSwitch { label: qsTr("Wave"); filterName: "wave" }
            FilterSwitch { label: qsTr("Ripple"); filterName: "ripple" }
            FilterSwitch { label: qsTr("Psychedelic"); filterName: "psychedelic" }
            RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("More Video Filters"); text: caption; onClicked: root.moreFiltersRequested() }
        }
    }
}
