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
            if (result.success) MediaLib.saveTrackAssignments(result.rows, root.subtitles, saved => root.finish(root.pendingSaveRequest, saved))
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
    onRowsRequested: (target, subtitles, request) => MediaLib.trackAssignmentRows(target, subtitles, result => root.loadRows(request, result))
    onSourcesRequested: (folder, subtitles, request) => MediaLib.trackAssignmentSources(folder, subtitles, result => root.loadSources(request, result))
    onMatchRequested: (media, tracks, includeSaved, request) => MediaLib.requestTrackMatches(media, tracks, matches => root.loadMatches(request, matches, includeSaved))
    onMatchingCanceled: MediaLib.cancelTrackMatching()
    onDroppedSourcesRequested: (urls, subtitles, request, target) => MediaLib.prepareTrackDrop(urls, subtitles, result => root.loadDroppedSources(request, result, target))
    onFilesRequested: target => root.addFiles(DialogsProvider.selectTrackFiles(root.subtitles, root.sourceFolder), target)
    onFolderRequested: {
        const folder = DialogsProvider.selectTrackFolder(root.sourceFolder)
        if (folder.toString().length) { root.sourceFolder = String(folder); root.requestSources(true) }
    }
    onSaveRequested: (rows, subtitles, request) => {
        if (rows.some(row => row.tracks.some(url => String(url).startsWith("opensubtitles:")))) {
            root.cancelableSave = true
            root.pendingSaveRequest = request
            root.pendingPreparation = SubtitleSources.prepareRows(rows)
        } else MediaLib.saveTrackAssignments(rows, subtitles, result => root.finish(request, result))
    }
    onSaved: (rows, subtitles) => restartNeeded = DialogsProvider.applySavedTrackAssignments(rows, subtitles) || restartNeeded
    onAccepted: if (restartNeeded) DialogsProvider.messageDialog(qsTr("Tracks saved. Stop and play this file to use all changes."), qsTr("VLC Media Player"))
}
