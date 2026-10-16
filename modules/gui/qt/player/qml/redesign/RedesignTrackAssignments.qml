// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import VLC.Player
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Dialogs
import VLC.Style

RedesignTrackAssignmentDialog {
    id: root
    property bool restartNeeded: false
    property double pendingSearch: -1
    property int pendingSearchRequest: -1
    property double pendingPreparation: -1
    property int pendingSaveRequest: -1
    providerConfigured: SubtitleSources.configured
    onlineLanguages: SubtitleSources.languages
    Connections {
        target: SubtitleSources
        function onSearchFinished(request, result) {
            if (request === root.pendingSearch) root.loadSearch(root.pendingSearchRequest, result)
        }
        function onPreparationFinished(request, result) {
            if (request !== root.pendingPreparation || !root.visible || root.pendingSaveRequest !== root.requestId) return
            root.cancelableSave = false
            root.resolveSources(result.resolved)
            const saveRequest = root.pendingSaveRequest
            if (result.success) MediaLib.saveTrackAssignments(result.rows, root.subtitles, saved => root.finish(saveRequest, saved))
            else root.finish(root.pendingSaveRequest, {success:false,error:result.error,saved:[]})
        }
    }
    scaleFactor: VLCStyle.scale
    lightTheme: !VLCStyle.palette.isDark
    accentColor: MainCtx.redesignAccent
    Binding {
        target: MainCtx; property: "useGlobalShortcuts"; value: false
        when: root.visible; restoreMode: Binding.RestoreBindingOrValue
    }
    onOpened: { restartNeeded = false; SubtitleSources.resetSession() }
    onClosed: SubtitleSources.resetSession()
    onSearchRequested: (query, language, request) => {
        pendingSearchRequest = request
        pendingSearch = SubtitleSources.search(query, language)
    }
    onSearchCanceled: SubtitleSources.cancelSearch()
    onLanguagesRequested: SubtitleSources.fetchLanguages()
    onSetupRequested: key => root.finishSetup(SubtitleSources.setApiKey(key))
    onApiKeyHelpRequested: Qt.openUrlExternally("https://www.opensubtitles.com/consumers")
    onLinksRequested: urls => root.loadLinkedSources(SubtitleSources.addLinks(urls))
    onRowsRequested: (target, subtitles, request) => MediaLib.trackAssignmentRows(target, subtitles, result => root.loadRows(request, result))
    onSourcesRequested: (folder, subtitles, request) => MediaLib.trackAssignmentSources(folder, subtitles, result => root.loadSources(request, result))
    onMatchRequested: (media, tracks, includeSaved, request) => MediaLib.requestTrackMatches(media, tracks, matches => root.loadMatches(request, matches, includeSaved))
    onMatchingCanceled: MediaLib.cancelTrackMatching()
    onDroppedSourcesRequested: (urls, subtitles, request, target) => {
        const remote = subtitles ? urls.filter(url => /^https?:/i.test(String(url))) : []
        const local = urls.filter(url => !remote.includes(url))
        const linked = remote.length ? SubtitleSources.addLinks(remote.map(String)) : {sources:[],error:""}
        const finish = result => root.loadDroppedSources(request, {
            success: result.success || linked.success,
            sources: (result.sources || []).concat(linked.sources || []),
            folder: result.folder || "",
            error: [result.error, linked.error].filter(value => value).join("\n")
        }, target)
        if (local.length) MediaLib.prepareTrackDrop(local, subtitles, finish)
        else finish({sources:[]})
    }
    onFilesRequested: target => root.addFiles(DialogsProvider.selectTrackFiles(root.subtitles, root.sourceFolder), target)
    onFolderRequested: {
        const folder = DialogsProvider.selectTrackFolder(root.sourceFolder)
        if (folder.toString().length) { root.sourceFolder = String(folder); root.requestSources(true) }
    }
    onSaveRequested: (rows, subtitles, request) => {
        if (rows.some(row => row.tracks.some(url => /^(?:opensubtitles|subtitlelink):/.test(String(url))))) {
            root.cancelableSave = true
            root.pendingSaveRequest = request
            root.pendingPreparation = SubtitleSources.prepareRows(rows)
        } else MediaLib.saveTrackAssignments(rows, subtitles, result => root.finish(request, result))
    }
    onSaved: (rows, subtitles) => restartNeeded = DialogsProvider.applySavedTrackAssignments(rows, subtitles) || restartNeeded
    onAccepted: if (restartNeeded) DialogsProvider.messageDialog(qsTr("Tracks saved. Stop and play this file to use all changes."), qsTr("VLC Media Player"))
}
