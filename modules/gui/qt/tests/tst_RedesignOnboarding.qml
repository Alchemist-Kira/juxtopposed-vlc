// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedOnboarding"
    width: 1090; height: 759
    visible: true; when: windowShown
    QtObject {
        id: setup
        property string defaultFolder: "~/Videos"
        property bool hasMediaLibrary: true
        property string errorMessage: ""
        property bool saveFails: false
        property var saved: ({})
        property var shortcuts: [{title: "Play / Pause", keys: ["Space"]}, {title: "Seek Backward / Forward", keys: ["Alt+Left", "Alt+Right"]}]
        function validateFolder(folder) { errorMessage = folder === "missing" ? "Select an existing folder." : ""; return !errorMessage.length }
        function browseFolder(folder) { return "/media/Movies" }
        function finish(folder, scheme, accent, network) {
            if (saveFails) { errorMessage = "VLC cannot save these settings."; return false }
            saved = {folder: folder, scheme: scheme, accent: accent, network: network}; return true
        }
    }
    RedesignOnboardingView { id: onboarding; anchors.fill: parent; backend: setup }
    SignalSpy { id: finished; target: onboarding; signalName: "finished" }
    SignalSpy { id: dismissed; target: onboarding; signalName: "dismissRequested" }
    function item(name) { return findChild(onboarding, name) }
    function init() {
        onboarding.page = 0; onboarding.folder = "~/Videos"; onboarding.scheme = 2
        onboarding.accentColor = "#d37918"; onboarding.onlineMetadata = true
        setup.hasMediaLibrary = true; setup.errorMessage = ""; setup.saveFails = false; setup.saved = ({})
        finished.clear(); dismissed.clear(); onboarding.width = 1090; onboarding.height = 759
    }
    function test_navigationUsesThreePagesAndRetainsEdits() {
        onboarding.folder = "/media/Music"; onboarding.next(); compare(onboarding.page, 1)
        mouseClick(item("onboardingScheme_1")); mouseClick(item("onboardingAccent_5"))
        onboarding.next(); compare(onboarding.page, 2)
        mouseClick(item("onboardingBack")); compare(onboarding.page, 1)
        compare(onboarding.scheme, 1); compare(onboarding.accentColor, "#185dd3")
        mouseClick(item("onboardingBack")); compare(onboarding.page, 0); compare(onboarding.folder, "/media/Music")
        compare(finished.count, 0)
    }
    function test_browseChangesOnlyTheFolder() {
        mouseClick(item("onboardingBrowse")); compare(onboarding.folder, "/media/Movies")
        compare(onboarding.page, 0); compare(finished.count, 0)
    }
    function test_missingFolderKeepsWelcomeVisible() {
        onboarding.folder = "missing"; onboarding.next(); compare(onboarding.page, 0)
        verify(item("onboardingError").visible)
    }
    function test_eachAccentAndThemeUpdatesTheRealPlayerPreview() {
        onboarding.page = 1
        for (let i = 0; i < 9; ++i) {
            mouseClick(item("onboardingAccent_" + i))
            compare(item("onboardingPlayerPreview").accentColor, onboarding.accents[i])
        }
        mouseClick(item("onboardingScheme_1")); compare(item("onboardingPlayerPreview").lightTheme, true)
        mouseClick(item("onboardingScheme_2")); compare(item("onboardingPlayerPreview").lightTheme, false)
        mouseClick(item("onboardingScheme_0")); onboarding.systemLight = true
        compare(item("onboardingPlayerPreview").lightTheme, true)
    }
    function test_finishIncludesMetadataChoiceAndAllSelections() {
        mouseClick(item("onboardingMetadata")); compare(onboarding.onlineMetadata, false)
        onboarding.next(); onboarding.next(); onboarding.next()
        compare(finished.count, 1); compare(setup.saved.folder, "~/Videos")
        compare(setup.saved.scheme, 2); compare(setup.saved.accent, "#d37918"); compare(setup.saved.network, false)
    }
    function test_saveFailureRetainsFinalPageAndAllowsRetry() {
        onboarding.page = 2; setup.saveFails = true; onboarding.next()
        compare(onboarding.page, 2); compare(finished.count, 0); verify(item("onboardingError").visible)
        setup.saveFails = false; onboarding.next(); compare(finished.count, 1)
    }
    function test_noMediaLibraryDisablesFolderControls() {
        setup.hasMediaLibrary = false; compare(item("onboardingFolder").enabled, false)
        compare(item("onboardingBrowse").enabled, false)
    }
    function test_privacyExplanationCanOpenAndClose() {
        mouseClick(item("onboardingPrivacyInfo")); verify(item("onboardingPrivacyPolicy").opened)
        keyClick(Qt.Key_Escape)
        tryCompare(item("onboardingPrivacyPolicy"), "visible", false)
        compare(dismissed.count, 0)
    }
}
