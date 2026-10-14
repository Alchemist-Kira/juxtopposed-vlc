// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedVideo"
    width: 400; height: 3400
    visible: true; when: windowShown
    QtObject {
        id: store
        property int revision: 0
        property var values: ({})
        property var live: ({})
        property string lastOption
        function value(name) { return values[name] }
        function videoValue(name) { return live[name] === undefined ? values[name] : live[name] }
        function describe(name) {
            if (name === "d3d11-hdr-mode") return {}
            if (["marq-opacity", "logo-opacity", "puzzle-rows", "puzzle-cols"].includes(name)) return {kind: "integer", minimum: 0, maximum: 255}
            if (["puzzle-preview", "brightness-threshold"].includes(name)) return {kind: "bool"}
            if (["marq-marquee", "marq-file", "logo-file", "erase-mask"].includes(name)) return {kind: "string", editor: name.endsWith("file") || name.endsWith("mask") ? "file" : ""}
            if (name === "preferred-resolution") return {kind: "integer", choices: [{label: "Best Available", value: -1}, {label: "720p", value: 720}]}
            if (name === "gradient-mode") return {kind: "string", choices: [{label: "Gradient", value: "gradient"}, {label: "Edge", value: "edge"}]}
            return {kind: "float"}
        }
        function stage(name, value) {
            lastOption = name
            const next = Object.assign({}, values)
            if (name.startsWith("filter:")) {
                const parts = name.split(":")
                const filters = String(videoValue(parts[1]) || "").split(":").filter(filter => filter && filter !== parts[2])
                if (value) filters.push(parts[2])
                next[parts[1]] = filters.join(":")
            } else next[name] = value
            values = next; live = {}; revision++
            return true
        }
        function chooseColor(initial) { return "#123456" }
        function choosePath(name) { return "/tmp/overlay.png" }
        function refresh() { revision++ }
        function reset(name) { stage(name, describe(name).defaultValue) }
    }
    RedesignVideoSettings { id: video; x: 24; width: 356; backend: store }
    function item(name) { return findChild(video, name) }
    function init() {
        store.values = {"video-filter": "", "transform-type": "90", "rotate-angle": 30, "fit": 1, "zoom": 1,
            "preferred-resolution": -1, "aspect-ratio": "", "crop": "", "hue": 0, "brightness": 1, "contrast": 1,
            "saturation": 1, "gamma": 1, "sharpen-sigma": .05, "gradfun-radius": 16, "grain-variance": 2,
            "extract-component": 16711680, "colorthres-color": 16711680, "colorthres-saturationthres": 20,
            "colorthres-similaritythres": 15, "gradient-mode": "gradient", "gradient-color": false,
            "gradient-cartoon": true, "sepia-intensity": 120,
            "sub-source": "", "sub-filter": "subsdelay", "marq-marquee": "VLC", "marq-file": "",
            "marq-opacity": 255, "marq-color": 16777215, "marq-position": -1, "marq-x": 0, "marq-y": 0,
            "marq-size": 0, "marq-timeout": 0, "marq-refresh": 1000,
            "logo-file": "", "logo-opacity": 255, "logo-position": -1, "logo-x": -1, "logo-y": -1,
            "logo-delay": 1000, "logo-repeat": -1,
            "puzzle-rows": 4, "puzzle-cols": 4, "puzzle-mode": 0, "puzzle-rotation": 0, "puzzle-border": 3,
            "puzzle-preview": false, "puzzle-preview-size": 15, "puzzle-shape-size": 90,
            "puzzle-auto-shuffle": 0, "puzzle-auto-solve": 0, "blur-factor": 80, "gaussianblur-sigma": 2,
            "antiflicker-window-size": 10, "antiflicker-softening-size": 10,
            "hqdn3d-luma-spat": 4, "hqdn3d-luma-temp": 6, "hqdn3d-chroma-spat": 3, "hqdn3d-chroma-temp": 4.5,
            "erase-mask": "", "erase-x": 0, "erase-y": 0, "anaglyph-scheme": "red-cyan"}
        store.live = {}; store.revision++; store.lastOption = ""
        video.width = 356
        for (const name of ["Essential", "Crop", "Colors", "Geometry", "Overlay", "Advanced"]) item("video" + name + "Section").expanded = false
        item("videoCropSection").contentItem.linkHorizontal = false
        item("videoCropSection").contentItem.linkVertical = false
        wait(30)
    }
    function test_groupsStartCollapsedInReferenceOrder() {
        let previous = -1
        for (const name of ["Essential", "Crop", "Colors", "Geometry", "Overlay", "Advanced"]) {
            const section = item("video" + name + "Section")
            verify(!section.expanded)
            verify(section.y > previous)
            previous = section.y
            compare(section.width, video.width + 4)
        }
        compare(item("zoomChoice").displayText, "1:1 Original")
        compare(item("aspect-ratioChoice").displayText, "Default")
        compare(item("videoRotation").currentValue, 0)
    }
    function test_narrowPanelKeepsDefaultsAndColorFieldsInsideItsBounds() {
        video.width = 244
        item("videoColorsSection").expanded = true
        wait(30)
        for (const name of ["zoomChoice", "preferred-resolutionChoice", "aspect-ratioChoice", "cropChoice", "videoRendererChoice", "videoColor_extract", "videoColor_colorthres"]) {
            const field = item(name)
            const point = field.mapToItem(video, 0, 0)
            verify(point.x >= -4, name)
            verify(point.x + field.width <= video.width + 1, name)
        }
        video.width = 356
    }
    function test_flipAndRotationRemainIndependent() {
        video.setFlip(1); compare(video.flip, 1)
        video.setRotation(45); compare(video.flip, 1); compare(video.rotationDegrees, 45)
        verify(video.enabledFilter("transform") && video.enabledFilter("rotate"))
        video.setRotation(0); compare(video.flip, 1); verify(!video.enabledFilter("rotate"))
        video.setFlip(0); compare(video.flip, 0); compare(store.values["video-filter"], "")
        store.stage("transform-type", "180"); video.effect("transform", true)
        compare(video.rotationDegrees, 180)
        video.setFlip(2); compare(video.flip, 2); compare(video.rotationDegrees, 180)
    }
    function test_quarterTurnsKeepTheWholeFrameAndLogicalFlipChoice() {
        const rows = [
            {angle: 90, types: ["90", "transpose", "antitranspose"]},
            {angle: 180, types: ["180", "vflip", "hflip"]},
            {angle: 270, types: ["270", "antitranspose", "transpose"]},
            {angle: -90, types: ["270", "antitranspose", "transpose"]}
        ]
        for (const row of rows) for (let flip = 0; flip <= 2; ++flip) {
            verify(video.setOrientation(row.angle, flip))
            compare(video.rotationDegrees, row.angle); compare(video.flip, flip)
            compare(store.values["transform-type"], row.types[flip])
            compare(store.values["video-filter"], "transform")
            compare(store.values["rotate-angle"], 0)
        }
        video.setRotation(0)
        compare(video.flip, 2); compare(store.values["transform-type"], "vflip")
        video.setFlip(0); compare(store.values["video-filter"], "")
    }
    function test_switchingFromQuarterToFreeAngleRetainsOtherEffects() {
        store.stage("video-filter", "adjust:sharpen")
        video.setOrientation(90, 1)
        compare(store.values["video-filter"], "adjust:sharpen:transform")
        video.setRotation(45)
        compare(video.flip, 1); compare(video.rotationDegrees, 45)
        compare(store.values["video-filter"], "adjust:sharpen:rotate:transform")
        compare(store.values["rotate-angle"], -45)
        video.setRotation(-180)
        compare(video.flip, 1); compare(video.rotationDegrees, -180)
        compare(store.values["video-filter"], "adjust:sharpen:transform")
        verify(!video.setRotation(NaN)); verify(!video.setRotation(361)); verify(!video.setFlip(3))
    }
    function test_externalNativeTransformChangesReplaceSavedLogicalHint() {
        video.setOrientation(180, 1)
        compare(store.values["transform-type"], "vflip")
        compare(video.rotationDegrees, 180); compare(video.flip, 1)
        store.live = {"video-filter": "transform", "transform-type": "90"}; store.revision++
        compare(video.rotationDegrees, 90); compare(video.flip, 0)
        store.live = {"video-filter": "rotate", "rotate-angle": 15}; store.revision++
        compare(video.rotationDegrees, -15); compare(video.flip, 0)
        store.stage("qt-video-transform-state", "invalid json")
        compare(video.rotationDegrees, 0); compare(video.flip, 2)
    }
    function test_zoomSetsPixelFittingWithoutChangingOtherDefaults() {
        const choice = item("zoomChoice")
        choice.currentIndex = 3; choice.activated(3)
        compare(store.values.fit, 0); compare(store.values.zoom, 2)
        compare(store.values.crop, ""); compare(store.values["aspect-ratio"], "")
    }
    function test_cropLinksOnlyTheSelectedPairAndPersistsBorders() {
        video.setBorder(1, 12); compare(store.values.crop, "0+12+0+0")
        item("videoCropSection").contentItem.linkVertical = true
        video.setBorder(3, 20); compare(store.values.crop, "0+20+0+20")
        item("videoCropSection").contentItem.linkHorizontal = true
        video.setBorder(0, 30); compare(store.values.crop, "30+20+30+20")
        verify(!video.setBorder(1, -1)); verify(!video.setBorder(0, 1.5))
        store.stage("crop", "16:9"); compare(video.borders().join("+"), "0+0+0+0")
        video.setBorder(2, 8); compare(store.values.crop, "8+0+8+0")
    }
    function test_cropTextRejectsBadInputAndReflectsExternalChanges() {
        const field = item("videoCropBorder_1")
        field.text = "15 px"; field.editingFinished(); compare(store.values.crop, "0+15+0+0")
        field.text = "1.5"; field.editingFinished(); compare(field.text, "15 px")
        store.live = {crop: "3+4+5+6"}; store.revision++
        compare(field.text, "4 px"); compare(item("cropChoice").displayText, "Custom")
    }
    function test_liveRefreshDoesNotReplaceTextWhileEditing() {
        item("videoCropSection").expanded = true
        const field = item("videoCropBorder_1")
        field.forceActiveFocus()
        compare(field.text, "0 px")
        field.text = "12"
        store.live = {crop: "1+2+3+4"}; store.revision++
        wait(500)
        compare(field.text, "12")
        field.editingFinished()
        compare(store.values.crop, "1+12+3+4")
        video.forceActiveFocus(); wait(20)
        store.live = {crop: "0+7+0+0"}; store.revision++
        compare(field.text, "7 px")
    }
    function test_essentialUsesCompactNativeRangesAndLiveValues() {
        const section = item("videoEssentialSection")
        mouseClick(findChild(section, "filterExpander")); verify(section.expanded)
        const slider = item("videoBrightness")
        verify(!findChild(slider, "settingValueField").visible)
        slider.moved(1.25); compare(store.values.brightness, 1.25)
        store.live = {brightness: .75}; store.revision++
        compare(slider.currentValue, .75)
        compare(item("videoHue").from, -180); compare(item("videoHue").to, 180)
        compare(item("videoBanding").from, 4); compare(item("videoBanding").to, 32)
        compare(item("videoGrain").to, 10)
    }
    function test_overlaySourcesKeepSubtitleFiltersAndVideoEffects() {
        store.stage("video-filter", "adjust:transform")
        item("videoTextOverlay").toggled(true)
        compare(store.values["sub-source"], "marq"); verify(item("videoTextOverlayOptions").visible === false)
        item("videoOverlaySection").expanded = true
        verify(item("videoTextOverlayOptions").visible)
        item("videoImageOverlay").toggled(true)
        compare(store.values["sub-source"], "marq:logo")
        item("videoTextOverlay").toggled(false)
        compare(store.values["sub-source"], "logo")
        compare(store.values["sub-filter"], "subsdelay"); compare(store.values["video-filter"], "adjust:transform")
    }
    function test_overlayOpacityUsesNativeAlphaAndTracksLiveChanges() {
        item("videoTextOpacity").moved(50)
        compare(store.values["marq-opacity"], 128)
        item("videoImageOpacity").moved(0); compare(store.values["logo-opacity"], 0)
        item("videoImageOpacity").moved(100); compare(store.values["logo-opacity"], 255)
        store.live = {"logo-opacity": 128}; store.revision++
        compare(item("videoImageOpacity").currentValue, 50)
    }
    function test_overlayTextCanBeEditedAcrossLiveRefresh() {
        item("videoOverlaySection").expanded = true
        const field = findChild(item("videoOverlayText"), "preferenceTextEditor")
        field.forceActiveFocus(); compare(field.text, "VLC")
        field.text = "A title"; store.revision++; wait(500); compare(field.text, "A title")
        field.editingFinished(); compare(store.values["marq-marquee"], "A title")
        video.forceActiveFocus(); store.live = {"marq-marquee": "New title"}; store.revision++
        compare(field.text, "New title")
    }
    function test_puzzleControlsUseNativeLimitsAndStayWithTheirEffect() {
        item("videoGeometrySection").expanded = true
        verify(!item("videoPuzzleOptions").visible)
        item("videoPuzzle").toggled(true); verify(item("videoPuzzleOptions").visible)
        item("videoPuzzleRows").moved(8); compare(store.values["puzzle-rows"], 8)
        compare(item("videoPuzzleColumns").from, 2); compare(item("videoPuzzleColumns").to, 42)
        item("videoPuzzle").toggled(false); verify(!item("videoPuzzleOptions").visible)
        compare(store.values["puzzle-rows"], 8)
    }
    function test_advancedParametersKeepFullNativeNumericInput() {
        compare(item("videoGaussianSigma").to, 8); compare(item("videoGaussianSigma").inputTo, 4096)
        item("videoGaussianSigma").moved(16); compare(store.values["gaussianblur-sigma"], 16)
        item("videoMotionBlurFactor").moved(99); compare(store.values["blur-factor"], 99)
    }
    function test_gradientModifiersShowAppliedStateAndCanEnableTheEffect() {
        const cartoon = item("videoGradientFlag_gradient-cartoon")
        const color = item("videoGradientFlag_gradient-color")
        verify(!findChild(cartoon, "settingSwitch").checked)
        cartoon.toggled(true)
        verify(video.enabledFilter("gradient")); verify(findChild(cartoon, "settingSwitch").checked)
        color.toggled(true); verify(findChild(color, "settingSwitch").checked)
        video.effect("gradient", false)
        verify(!findChild(cartoon, "settingSwitch").checked)
        verify(!findChild(color, "settingSwitch").checked)
        compare(store.values["gradient-cartoon"], true); compare(store.values["gradient-color"], true)
    }
    function test_colorEditsPreserveSwitchStateAndRejectInvalidHex() {
        const field = item("videoColor_extract")
        field.text = "#123456"; field.editingFinished()
        compare(store.values["extract-component"], 1193046)
        verify(!video.enabledFilter("extract"))
        field.text = "#zzzzzz"; field.editingFinished(); compare(field.text, "#123456")
        const mode = item("videoGradientMode")
        mode.currentIndex = 1; mode.activated(1); compare(store.values["gradient-mode"], "edge")
        verify(!video.enabledFilter("gradient"))
    }
}
