// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedPlayerPreset"
    width: 800; height: 800
    visible: true; when: windowShown
    QtObject {
        id: store
        property int revision: 0
        property var playerPresets: []
        property string selectedPlayerPreset
        property bool pendingPlayerPreset: false
        property string errorMessage
        property string lastAction
        property string lastId
        property string lastName
        property bool failSave: false
        function record(action, id, name) {
            lastAction = action; lastId = id || ""; lastName = name || ""
            pendingPlayerPreset = failSave
            errorMessage = failSave ? "The file could not be saved." : ""
            revision++
            return !failSave
        }
        function save() { return record("retry", "", "") }
        function createPlayerPreset(name) { return record("create", "", name) }
        function selectPlayerPreset(id) { selectedPlayerPreset = id; return record("select", id, "") }
        function renamePlayerPreset(id, name) { return record("rename", id, name) }
        function duplicatePlayerPreset(id, name) { return record("duplicate", id, name) }
        function deletePlayerPreset(id) { return record("delete", id, "") }
    }
    RedesignPlayerPreset { id: selector; x: 200; y: 600; width: 360; backend: store }
    function item(name) { return findChild(selector, name) }
    function init() {
        item("playerPresetMenu").close(); item("playerPresetActions").close()
        item("playerPresetNameDialog").close(); item("playerPresetDeleteDialog").close()
        store.playerPresets = [{id: "show", name: "My Show"}, {id: "quiet", name: "Quiet Movies"}]
        store.selectedPlayerPreset = ""; store.pendingPlayerPreset = false
        store.errorMessage = ""; store.lastAction = ""; store.failSave = false; store.revision++
        wait(10)
    }
    function test_selectionUsesSavedNamesAndKeyboard() {
        compare(selector.selectedName, "Default Preset")
        mouseClick(item("playerPresetSelector"))
        tryCompare(item("playerPresetMenu"), "opened", true)
        verify(item("playerPresetMenu").y < 0)
        keyClick(Qt.Key_Up); keyClick(Qt.Key_Return)
        compare(store.lastAction, "select"); compare(store.lastId, "quiet")
        compare(selector.selectedName, "Quiet Movies")
        verify(!item("playerPresetMenu").visible)
    }
    function test_defaultRestoresByStableEmptyId() {
        store.selectedPlayerPreset = "show"
        mouseClick(item("playerPresetSelector"))
        tryCompare(item("playerPresetMenu"), "opened", true)
        keyClick(Qt.Key_End); keyClick(Qt.Key_Return)
        compare(store.lastId, ""); compare(store.lastAction, "select")
    }
    function test_createUsesNameDialog() {
        mouseClick(item("playerPresetSelector"))
        tryCompare(item("playerPresetMenu"), "opened", true)
        keyClick(Qt.Key_Home); keyClick(Qt.Key_Return)
        tryCompare(item("playerPresetNameDialog"), "opened", true)
        item("playerPresetName").text = "Anime"
        mouseClick(item("playerPresetNameSave"))
        compare(store.lastAction, "create"); compare(store.lastName, "Anime")
        verify(!item("playerPresetNameDialog").visible)
    }
    function test_renameAndDuplicateKeepIdentity() {
        for (const action of ["rename", "duplicate"]) {
            selector.namePreset(action, "show", "My Show")
            tryCompare(item("playerPresetNameDialog"), "opened", true)
            compare(item("playerPresetName").text, action === "rename" ? "My Show" : "")
            item("playerPresetName").text = "New Name"
            mouseClick(item("playerPresetNameSave"))
            compare(store.lastAction, action); compare(store.lastId, "show"); compare(store.lastName, "New Name")
        }
    }
    function test_actionsOpenFromKeyboard() {
        mouseClick(item("playerPresetSelector"))
        tryCompare(item("playerPresetMenu"), "opened", true)
        keyClick(Qt.Key_Home); keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)
        tryCompare(item("playerPresetActions"), "opened", true)
        keyClick(Qt.Key_Home); keyClick(Qt.Key_Return)
        tryCompare(item("playerPresetNameDialog"), "opened", true)
        compare(selector.nameAction, "rename")
        compare(selector.contextId, "show")
    }
    function test_deleteActionOpensConfirmationFromKeyboard() {
        mouseClick(item("playerPresetSelector"))
        tryCompare(item("playerPresetMenu"), "opened", true)
        keyClick(Qt.Key_Home); keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)
        tryCompare(item("playerPresetActions"), "opened", true)
        keyClick(Qt.Key_End); keyClick(Qt.Key_Return)
        tryCompare(item("playerPresetDeleteDialog"), "opened", true)
        compare(store.lastAction, "")
    }
    function test_failedCreationRetriesSameTransaction() {
        selector.namePreset("create", "", "")
        tryCompare(item("playerPresetNameDialog"), "opened", true)
        item("playerPresetName").text = "Anime"; store.failSave = true
        mouseClick(item("playerPresetNameSave"))
        verify(item("playerPresetNameDialog").visible)
        verify(item("playerPresetName").readOnly)
        verify(!item("playerPresetSelector").enabled)
        store.failSave = false
        mouseClick(item("playerPresetNameSave"))
        compare(store.lastAction, "retry")
        verify(!item("playerPresetNameDialog").visible)
        verify(item("playerPresetSelector").enabled)
    }
    function test_deleteRequiresConfirmation() {
        selector.contextId = "show"; selector.contextName = "My Show"
        item("playerPresetDeleteDialog").open()
        tryCompare(item("playerPresetDeleteDialog"), "opened", true)
        keyClick(Qt.Key_Escape)
        compare(store.lastAction, "")
        item("playerPresetDeleteDialog").open()
        tryCompare(item("playerPresetDeleteDialog"), "opened", true)
        mouseClick(findChild(item("playerPresetDeleteDialog"), "confirmationAccept"))
        compare(store.lastAction, "delete"); compare(store.lastId, "show")
    }
}
