// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style

RedesignAddToPlaylistDialog {
    id: root
    property var sources: []
    scaleFactor: VLCStyle.scale
    lightTheme: !VLCStyle.palette.isDark
    accentColor: MainCtx.redesignAccent
    playlistModel: playlists
    function beginSelection(items, type) {
        if (visible || items.length === 0) return
        sources = items.slice()
        playlists.playlistType = type
        begin(sources.length)
    }
    Binding {
        target: MainCtx; property: "useGlobalShortcuts"; value: false
        when: root.visible; restoreMode: Binding.RestoreBindingOrValue
    }
    onSaveRequested: (key, name) => playlists.saveSelection(MediaLib.deserializeMlItemIdFromString(key), name, sources)
    onClosed: sources = []
    MLPlaylistListModel {
        id: playlists
        ml: MediaLib
        searchPattern: root.filterText
        sortCriteria: "title"
        onSelectionSaved: (success, id, error) => root.finish(success, error)
    }
}
