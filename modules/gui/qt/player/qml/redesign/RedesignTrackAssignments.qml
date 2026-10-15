// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Dialogs
import VLC.Style

RedesignTrackAssignmentDialog {
    id: root
    property bool restartNeeded: false
    scaleFactor: VLCStyle.scale
    lightTheme: !VLCStyle.palette.isDark
    accentColor: MainCtx.redesignAccent
    Binding {
        target: MainCtx; property: "useGlobalShortcuts"; value: false
        when: root.visible; restoreMode: Binding.RestoreBindingOrValue
    }
    onOpened: restartNeeded = false
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
    onSaveRequested: (rows, subtitles, request) => MediaLib.saveTrackAssignments(rows, subtitles, result => root.finish(request, result))
    onSaved: (rows, subtitles) => restartNeeded = DialogsProvider.applySavedTrackAssignments(rows, subtitles) || restartNeeded
    onAccepted: if (restartNeeded) DialogsProvider.messageDialog(qsTr("Tracks saved. Stop and play this file to use all changes."), qsTr("VLC Media Player"))
}
