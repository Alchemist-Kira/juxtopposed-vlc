// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

C.Dialog {
    id: root
    property real scaleFactor: 1
    property bool lightTheme: false
    property color accentColor: "#d37918"
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    property bool subtitles: true
    property var context: ({})
    property var rows: []
    property var sources: []
    property var drafts: ({})
    property var selectedRows: ({})
    property string anchorFile: ""
    property string targetFolder: ""
    property string sourceFolder: ""
    property int scopeIndex: 0
    onScopeIndexChanged: Qt.callLater(() => scopeChoice.currentIndex = root.scopeIndex)
    property int requestId: 0
    property int sourceRequestId: 0
    property bool loading: false
    property bool loadingSources: false
    property bool matchSavedSources: false
    property bool matching: false
    property int matchRequestId: 0
    property bool loadingDrop: false
    property int dropRequestId: 0
    property bool saving: false
    property string errorMessage: ""
    readonly property bool fileMode: scopeIndex === 0
    readonly property var scopes: [
        {text: qsTr("To This File"), enabled: anchorFile.length > 0},
        {text: qsTr("To Folder"), enabled: targetFolder.length > 0},
        {text: qsTr("To Playlist"), enabled: !!context.key || (context.urls || []).length > 0}
    ]
    readonly property var changedRows: Object.keys(drafts).map(url => drafts[url]).filter(row => !same(row.initialTracks, row.tracks))
    readonly property var visibleSources: {
        const result = sources.slice()
        const seen = result.map(item => item.url)
        for (const row of rows) for (const url of tracks(row.url))
            if (!seen.includes(url)) { seen.push(url); result.push({url: url, name: fileName(url)}) }
        return result
    }
    signal rowsRequested(var target, bool subtitles, int request)
    signal sourcesRequested(url folder, bool subtitles, int request)
    signal matchRequested(var media, var tracks, bool includeSaved, int request)
    signal matchingCanceled()
    signal droppedSourcesRequested(var urls, bool subtitles, int request, string target)
    signal filesRequested(string target)
    signal folderRequested()
    signal saveRequested(var rows, bool subtitles, int request)
    signal saved(var rows, bool subtitles)
    title: subtitles ? qsTr("Add Subtitles") : qsTr("Add Audio Tracks")
    anchors.centerIn: parent
    width: Math.min(theme.dp(1048), parent ? parent.width - theme.dp(32) : theme.dp(1048))
    height: Math.min(theme.dp(800), parent ? parent.height - theme.dp(32) : theme.dp(800))
    padding: 0; modal: true; dim: true; focus: true
    closePolicy: saving ? C.Popup.NoAutoClose : C.Popup.CloseOnEscape
    background: Rectangle { color: root.theme.floatingPanel; radius: root.theme.dp(14) }
    C.Overlay.modal: Rectangle { color: "#80000000" }

    function fileName(url) {
        const name = String(url).split("/").pop()
        try { return decodeURIComponent(name) } catch (error) { return name }
    }
    function parentFolder(url) { return String(url).startsWith("file:") ? String(url).substring(0, String(url).lastIndexOf("/") + 1) : "" }
    function same(a, b) { return [...new Set(a || [])].sort().join("\n") === [...new Set(b || [])].sort().join("\n") }
    function tracks(url) { return drafts[url] ? drafts[url].tracks : [] }
    function begin(target, subtitleMode) {
        if (visible || saving) return false
        context = target; subtitles = subtitleMode
        rows = []; sources = []; drafts = ({}); selectedRows = ({}); errorMessage = ""
        anchorFile = target.scope === "folder" || target.scope === "playlist" ? "" : String(target.url || "")
        targetFolder = target.scope === "folder" ? String(target.folder || target.url || "") : parentFolder(anchorFile)
        sourceFolder = targetFolder
        scopeIndex = target.scope === "folder" ? 1 : ["playlist", "queue"].includes(target.scope) ? 2 : 0
        open(); requestRows()
        return true
    }
    function cancelMatching() { ++matchRequestId; matching = false; matchingCanceled() }
    function requestRows() {
        ++dropRequestId; loadingDrop = false
        cancelMatching()
        ++requestId; loading = true; errorMessage = ""; selectedRows = ({})
        const target = scopeIndex === 0 ? {scope: "file", url: anchorFile}
            : scopeIndex === 1 ? {scope: "folder", folder: targetFolder}
            : context.key ? {scope: "playlist", key: context.key} : {scope: "queue", urls: context.urls || []}
        target.runtimeUrl = context.runtimeUrl
        target.runtimeTracks = context.runtimeTracks
        rowsRequested(target, subtitles, requestId)
    }
    function loadRows(request, result) {
        if (!visible || request !== requestId) return
        loading = false
        if (!result.success) { rows = []; errorMessage = result.error || qsTr("VLC cannot read these files. Try again."); return }
        rows = result.rows || []
        const next = Object.assign({}, drafts)
        for (const row of rows) if (!next[row.url] || same(next[row.url].initialTracks, next[row.url].tracks)) next[row.url] = {
            url: row.url, baseline: Array.from(row.baseline || []),
            initialTracks: Array.from(row.initialTracks || row.baseline || []),
            tracks: Array.from(row.initialTracks || row.baseline || []),
            explicitSelection: !!row.explicitSelection, manual: false
        }
        drafts = next
        if (!anchorFile && rows.length) anchorFile = rows[0].url
        if (!targetFolder) targetFolder = parentFolder(anchorFile)
        if (!sourceFolder && targetFolder) sourceFolder = targetFolder
        if (sourceFolder) requestSources()
        else performMatching()
    }
    function requestSources(includeSaved = false) {
        ++dropRequestId; loadingDrop = false
        cancelMatching()
        matchSavedSources = includeSaved
        ++sourceRequestId; loadingSources = true
        sourcesRequested(sourceFolder, subtitles, sourceRequestId)
    }
    function loadSources(request, result) {
        if (!visible || request !== sourceRequestId) return
        loadingSources = false
        if (!result.success) { errorMessage = result.error || qsTr("VLC cannot read this folder. Try again."); return }
        sources = result.sources || []; performMatching(matchSavedSources)
    }
    function performMatching(includeSaved = false) {
        cancelMatching()
        if (!fileMode && !loading && !loadingSources) {
            matching = true
            matchRequested(rows.map(row => row.url), sources.map(source => source.url), includeSaved, matchRequestId)
        }
    }
    function loadMatches(request, matches, includeSaved = false) {
        if (!visible || request !== matchRequestId) return
        matching = false
        applyMatches(matches, includeSaved)
    }
    function applyMatches(matches, includeSaved = false) {
        const next = Object.assign({}, drafts)
        for (const row of rows) {
            const draft = next[row.url]
            if (draft && !draft.manual && (!draft.explicitSelection || includeSaved)) next[row.url] = Object.assign({}, draft,
                {tracks: [...new Set(draft.initialTracks.concat(matches[row.url] || []))]})
        }
        drafts = next
    }
    function setTracks(url, selection) {
        const draft = drafts[url]
        if (!draft || saving) return
        drafts = Object.assign({}, drafts, {[url]: Object.assign({}, draft, {tracks: [...new Set(selection)], manual: true})})
        errorMessage = ""
    }
    function toggle(url, track) {
        const selected = tracks(url)
        setTracks(url, selected.includes(track) ? selected.filter(item => item !== track) : selected.concat([track]))
    }
    function addFiles(files, target) {
        addSources(files.map(value => ({url: String(value), name: fileName(value)})), target)
    }
    function addSources(items, target) {
        if (!items.length) return
        const next = sources.slice()
        for (const item of items) if (!next.some(source => source.url === item.url)) next.push(item)
        sources = next
        const url = target || (fileMode ? anchorFile : "")
        if (url) setTracks(url, tracks(url).concat(items.map(item => item.url)))
        else performMatching(true)
    }
    function dropSources(urls, target = "") {

        if (!visible || saving || loading || loadingDrop) return false
        if (!urls.length) { errorMessage = qsTr("VLC could not read these files. Try again."); return false }
        cancelMatching(); ++sourceRequestId; loadingSources = false
        ++dropRequestId; loadingDrop = true; errorMessage = ""
        droppedSourcesRequested(urls, subtitles, dropRequestId, target)
        return true
    }
    function loadDroppedSources(request, result, target = "") {

        if (!visible || request !== dropRequestId) return
        loadingDrop = false
        if (result.success) {
            if (result.folder) sourceFolder = String(result.folder)
            addSources(result.sources || [], target)
        }
        errorMessage = result.error || ""
    }
    function selectScope(index) {
        if (index === scopeIndex || !scopes[index].enabled || saving || loadingDrop) return
        scopeIndex = index; picker.close(); requestRows()
    }
    function chooseRow(url) { picker.targetUrl = url; picker.open() }
    function submit() {
        if (saving || loading || loadingSources || loadingDrop || matching || !changedRows.length) return
        saving = true; picker.close(); errorMessage = ""
        saveRequested(changedRows, subtitles, requestId)
    }
    function finish(request, result) {
        if (!visible || request !== requestId) return
        saving = false
        const completed = result.saved || []
        const next = Object.assign({}, drafts)
        for (const row of completed) if (next[row.url]) next[row.url] = Object.assign({}, next[row.url], {baseline: Array.from(row.tracks), initialTracks: Array.from(row.tracks), tracks: Array.from(row.tracks), explicitSelection: true})
        drafts = next
        if (completed.length) saved(completed, subtitles)
        if (result.success) accept()
        else errorMessage = (result.error || qsTr("VLC cannot save these tracks. Try again."))
            + (completed.length ? "\n" + qsTr("VLC kept the changes that it saved. Try Save again for the other files.") : "")
    }
    onClosed: { ++dropRequestId; loadingDrop = false; cancelMatching(); ++requestId; ++sourceRequestId; picker.close(); rows = []; sources = []; drafts = ({}); selectedRows = ({}) }
    Shortcut { sequences: ["Ctrl+Return", "Ctrl+Enter"]; enabled: root.visible && !root.saving; onActivated: root.submit() }

    header: Item {
        implicitHeight: root.theme.dp(96)
        Rectangle {
            anchors.fill: parent; radius: root.theme.dp(14); color: root.theme.field
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height / 2; color: parent.color }
        }
        Text {
            x: root.theme.dp(20); y: root.theme.dp(16)
            text: root.title; color: root.theme.foreground; font.pixelSize: root.theme.dp(14)
        }
        RedesignButton {
            objectName: "trackAssignmentClose"
            anchors.right: parent.right; anchors.rightMargin: root.theme.dp(8); y: root.theme.dp(6)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            iconName: "close"; text: qsTr("Close"); enabled: !root.saving; onClicked: root.reject()
        }
        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: root.theme.dp(9); anchors.rightMargin: root.theme.dp(9); anchors.bottomMargin: root.theme.dp(9)
            spacing: root.theme.dp(10)
            RedesignComboBox {
                id: scopeChoice
                objectName: "trackAssignmentScope"
                Layout.preferredWidth: Math.min(root.theme.dp(200), root.width * 0.23); Layout.preferredHeight: root.theme.dp(34)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                model: root.scopes; textRole: "text"; restrictChoices: true
                currentIndex: root.scopeIndex; enabled: !root.loading && !root.loadingDrop && !root.saving
                onModelChanged: Qt.callLater(() => scopeChoice.currentIndex = root.scopeIndex)
                background: Rectangle { color: root.theme.panel; radius: root.theme.dp(4); border.color: parent.visualFocus ? root.theme.accent : "transparent" }
                onActivated: index => root.selectScope(index)
            }
            RedesignButton {
                objectName: "trackAssignmentFiles"
                Layout.preferredWidth: Math.min(root.theme.dp(200), root.width * 0.23); Layout.preferredHeight: root.theme.dp(34)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                caption: qsTr("From Computer"); text: qsTr("Select track files"); leftAligned: true
                enabled: !root.loading && !root.loadingDrop && !root.saving
                background: Rectangle { color: root.theme.panel; radius: root.theme.dp(4); border.color: parent.visualFocus ? root.theme.accent : "transparent" }
                onClicked: root.filesRequested("")
            }
            RedesignButton {
                objectName: "trackAssignmentFolder"
                Layout.fillWidth: true; Layout.preferredHeight: root.theme.dp(34)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                iconName: "folder"; text: root.sourceFolder || qsTr("Select track folder"); leftAligned: true
                enabled: !root.saving && !root.loadingDrop
                background: Rectangle { color: root.theme.panel; radius: root.theme.dp(4); border.color: parent.visualFocus ? root.theme.accent : "transparent" }
                contentItem: RowLayout {
                    spacing: root.theme.dp(12)
                    RedesignIcon { sourceSize: Qt.size(root.theme.dp(40), root.theme.dp(40)); Layout.leftMargin: root.theme.dp(10); Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: width; name: "folder"; color: root.theme.foreground }
                    Text { Layout.fillWidth: true; Layout.rightMargin: root.theme.dp(12); text: root.sourceFolder ? decodeURIComponent(root.sourceFolder.replace(/^file:\/\//, "")) : qsTr("Select track folder"); elide: Text.ElideMiddle; font.pixelSize: root.theme.dp(14); color: root.theme.foreground }
                }
                onClicked: root.folderRequested()
            }
        }
    }
    contentItem: Item {
        DropArea {
            id: fileDrop
            objectName: "trackAssignmentDropArea"
            anchors.fill: parent
            enabled: root.visible && !root.saving && !root.loading && !root.loadingDrop
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => {
                drop.accepted = false
                if (drop.hasUrls && root.dropSources(drop.urls)) drop.accept(Qt.CopyAction)
            }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: root.theme.dp(12); z: 4
            visible: fileDrop.containsDrag
            color: Qt.alpha(root.theme.field, 0.95); radius: root.theme.dp(8)
            border.color: root.theme.accent; border.width: root.theme.dp(2)
            Text {
                anchors.centerIn: parent; width: parent.width - root.theme.dp(40); wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: root.subtitles ? qsTr("Drop subtitle files or folders here") : qsTr("Drop audio files or folders here")
                color: root.theme.foreground; font.pixelSize: root.theme.dp(18)
            }
        }
        C.ScrollView {
            anchors.fill: parent; anchors.topMargin: root.theme.dp(20); anchors.leftMargin: root.theme.dp(20); anchors.rightMargin: root.theme.dp(20)
            clip: true; contentWidth: availableWidth
            C.ScrollBar.horizontal.policy: C.ScrollBar.AlwaysOff
            ListView {
                id: list
                objectName: "trackAssignmentList"
                model: root.loading ? [] : root.fileMode ? root.visibleSources : root.rows
                spacing: root.theme.dp(4)
                delegate: C.ItemDelegate {
                    id: entry
                    required property var modelData
                    required property int index
                    objectName: "trackAssignmentRow_" + index
                    width: ListView.view.width; height: root.theme.dp(36)
                    enabled: !root.saving; padding: root.theme.dp(10)
                    highlighted: root.fileMode && root.tracks(root.anchorFile).includes(modelData.url)
                    Accessible.name: modelData.name
                    background: Rectangle { radius: root.theme.dp(5); color: entry.highlighted ? root.theme.field : entry.hovered ? root.theme.hover : "transparent"; border.color: entry.visualFocus || rowDrop.containsDrag ? root.theme.accent : "transparent" }
                    DropArea {
                        id: rowDrop
                        objectName: "trackAssignmentRowDrop_" + entry.index
                        anchors.fill: parent
                        enabled: !root.fileMode && !root.saving && !root.loadingDrop
                        onEntered: drag => drag.accepted = drag.hasUrls
                        onDropped: drop => {
                            drop.accepted = false
                            if (drop.hasUrls && root.dropSources(drop.urls, entry.modelData.url)) drop.accept(Qt.CopyAction)
                        }
                    }
                    onClicked: root.fileMode ? root.toggle(root.anchorFile, modelData.url) : root.chooseRow(modelData.url)
                    contentItem: RowLayout {
                        spacing: root.theme.dp(18)
                        C.CheckBox {
                            visible: !root.fileMode
                            Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: root.theme.dp(24)
                            checked: !!root.selectedRows[entry.modelData.url]
                            Accessible.name: qsTr("Select %1").arg(entry.modelData.name)
                            onToggled: root.selectedRows = Object.assign({}, root.selectedRows, {[entry.modelData.url]: checked})
                            indicator: Rectangle { x: root.theme.dp(2); y: (parent.height - height) / 2; width: root.theme.dp(16); height: width; radius: root.theme.dp(2); color: "transparent"; border.color: parent.visualFocus ? root.theme.accent : root.theme.foreground
                                RedesignIcon { sourceSize: Qt.size(root.theme.dp(40), root.theme.dp(40)); anchors.fill: parent; anchors.margins: root.theme.dp(1); name: "check"; color: root.theme.accent; visible: parent.parent.checked }
                            }
                            contentItem: Item {}
                        }
                        RedesignIcon { sourceSize: Qt.size(root.theme.dp(40), root.theme.dp(40)); visible: root.fileMode; Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: width; name: root.subtitles ? "subtitle-file" : "audio-file"; color: root.theme.foreground }
                        Text {
                            Layout.fillWidth: root.fileMode; Layout.preferredWidth: root.fileMode ? -1 : root.theme.dp(160)
                            text: entry.modelData.name; font.pixelSize: root.theme.dp(14); color: root.theme.foreground; elide: Text.ElideMiddle
                        }
                        Item {
                            visible: !root.fileMode; Layout.fillWidth: true; Layout.preferredWidth: root.theme.dp(280); Layout.preferredHeight: root.theme.dp(1)
                            Row { anchors.fill: parent; spacing: root.theme.dp(8); clip: true
                                Repeater { model: Math.ceil(parent.width / root.theme.dp(16)); Rectangle { width: root.theme.dp(8); height: root.theme.dp(1); color: root.theme.border } }
                            }
                        }
                        RedesignButton {
                            visible: !root.fileMode
                            objectName: "trackAssignmentChoose_" + entry.index
                            Layout.fillWidth: true; Layout.preferredWidth: root.theme.dp(460); Layout.preferredHeight: root.theme.dp(32)
                            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                            iconName: root.subtitles ? "subtitle-file" : "audio-file"; leftAligned: true
                            text: qsTr("Select tracks for %1").arg(entry.modelData.name)
                            contentItem: RowLayout {
                                spacing: root.theme.dp(12)
                                RedesignIcon { sourceSize: Qt.size(root.theme.dp(40), root.theme.dp(40)); Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: root.theme.dp(20); name: root.subtitles ? "subtitle-file" : "audio-file"; color: root.theme.foreground }
                                Text { Layout.fillWidth: true; text: root.tracks(entry.modelData.url).length ? root.tracks(entry.modelData.url).map(url => root.fileName(url)).join(", ") : qsTr("Select tracks"); elide: Text.ElideMiddle; color: root.theme.foreground; font.pixelSize: root.theme.dp(14) }
                            }
                            onClicked: root.chooseRow(entry.modelData.url)
                        }
                        RedesignIcon { sourceSize: Qt.size(root.theme.dp(40), root.theme.dp(40)); visible: entry.highlighted; Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: width; name: "check"; color: root.theme.accent }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent; width: parent.width - root.theme.dp(40); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            visible: root.loading || root.loadingSources || root.loadingDrop || root.matching || (!list.count && !root.errorMessage)
            text: root.matching ? qsTr("Matching tracks…") : root.loading || root.loadingSources || root.loadingDrop ? qsTr("Loading files…") : root.fileMode ? qsTr("Select a folder or choose track files from your computer.") : qsTr("There are no media files here.")
            color: root.theme.foreground; font.pixelSize: root.theme.dp(14)
        }
    }
    footer: Item {
        implicitHeight: root.theme.dp(72) + (error.visible ? error.implicitHeight + root.theme.dp(12) : 0)
        Text {
            id: error
            objectName: "trackAssignmentError"
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: root.theme.dp(20); anchors.topMargin: root.theme.dp(4)
            visible: root.errorMessage.length > 0; text: root.errorMessage; wrapMode: Text.WordWrap
            font.pixelSize: root.theme.dp(14); color: root.theme.danger; Accessible.role: Accessible.AlertMessage
        }
        RedesignButton {
            objectName: "trackAssignmentCancel"
            x: root.theme.dp(20); anchors.bottom: parent.bottom; anchors.bottomMargin: root.theme.dp(20)
            implicitWidth: root.theme.dp(100); implicitHeight: root.theme.dp(32)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            caption: qsTr("Cancel"); text: caption; enabled: !root.saving; onClicked: root.reject()
            background: Rectangle { radius: root.theme.dp(5); color: parent.hovered ? root.theme.hover : root.theme.background; border.color: parent.visualFocus ? root.theme.accent : "transparent" }
        }
        RedesignButton {
            objectName: "trackAssignmentClearSelected"
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: root.theme.dp(20)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            visible: !root.fileMode && Object.values(root.selectedRows).some(value => value)
            caption: qsTr("Clear selected tracks"); text: caption; enabled: !root.saving
            onClicked: { for (const url of Object.keys(root.selectedRows)) if (root.selectedRows[url]) root.setTracks(url, []) }
        }
        RedesignButton {
            objectName: "trackAssignmentSave"
            anchors.right: parent.right; anchors.rightMargin: root.theme.dp(20); anchors.bottom: parent.bottom; anchors.bottomMargin: root.theme.dp(20)
            implicitWidth: root.theme.dp(100); implicitHeight: root.theme.dp(32)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            caption: root.saving ? qsTr("Saving…") : qsTr("Save"); text: caption
            enabled: !root.saving && !root.loading && !root.loadingSources && !root.loadingDrop && !root.matching && root.changedRows.length > 0
            foreground: root.theme.accent
            background: Rectangle { radius: root.theme.dp(5); color: root.theme.progress; border.color: parent.visualFocus ? root.theme.accent : "transparent"; opacity: parent.enabled ? 1 : 0.4 }
            onClicked: root.submit()
        }
    }
    C.Popup {
        id: picker
        property string targetUrl: ""
        objectName: "trackAssignmentPicker"
        anchors.centerIn: parent
        width: Math.min(root.theme.dp(640), root.width - root.theme.dp(40))
        height: Math.min(root.theme.dp(460), root.height - root.theme.dp(80))
        padding: root.theme.dp(12); modal: true; focus: true
        background: Rectangle { color: root.theme.panel; radius: root.theme.dp(8); border.color: root.theme.border }
        contentItem: ColumnLayout {
            spacing: root.theme.dp(10)
            Text { Layout.fillWidth: true; text: root.fileName(picker.targetUrl); elide: Text.ElideMiddle; color: root.theme.bright; font.pixelSize: root.theme.dp(14) }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                model: root.visibleSources
                DropArea {
                    objectName: "trackAssignmentPickerDropArea"
                    anchors.fill: parent
                    enabled: picker.visible && !root.saving && !root.loadingDrop
                    onEntered: drag => drag.accepted = drag.hasUrls
                    onDropped: drop => {
                        drop.accepted = false
                        if (drop.hasUrls && root.dropSources(drop.urls, picker.targetUrl)) drop.accept(Qt.CopyAction)
                    }
                }
                C.ScrollBar.vertical: C.ScrollBar {}
                delegate: C.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width; height: root.theme.dp(36)
                    text: modelData.name; highlighted: root.tracks(picker.targetUrl).includes(modelData.url)
                    onClicked: root.toggle(picker.targetUrl, modelData.url)
                    background: Rectangle { radius: root.theme.dp(4); color: parent.highlighted ? root.theme.field : parent.hovered ? root.theme.hover : "transparent"; border.color: parent.visualFocus ? root.theme.accent : "transparent" }
                    contentItem: RowLayout {
                        Text { Layout.fillWidth: true; text: parent.parent.text; elide: Text.ElideMiddle; color: root.theme.foreground; font.pixelSize: root.theme.dp(14) }
                        RedesignIcon { sourceSize: Qt.size(root.theme.dp(40), root.theme.dp(40)); Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: root.theme.dp(20); name: "check"; color: root.theme.accent; visible: parent.parent.highlighted }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Choose files…"); text: caption; onClicked: root.filesRequested(picker.targetUrl) }
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Clear"); text: caption; onClicked: root.setTracks(picker.targetUrl, []) }
                Item { Layout.fillWidth: true }
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor; caption: qsTr("Done"); text: caption; onClicked: picker.close() }
            }
        }
    }
}
