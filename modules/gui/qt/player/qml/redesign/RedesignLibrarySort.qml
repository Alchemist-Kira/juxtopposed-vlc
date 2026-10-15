// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

QtObject {
    id: root
    property var ctx
    property string scope: "media"
    property var fields: ["played", "insertion", "title", "main_artist", "album_title", "track_number", "uri", "disc_number"]
    property string defaultChoice: "unwatched"
    property var extraOptions: []
    property var saved: ({})
    property bool ready: false
    readonly property string storageKey: "Juxtopposed/library-sort"
    readonly property var catalog: [
        {id: "unwatched", field: "played", descending: false, label: qsTr("Unwatched First")},
        {id: "watched", field: "played", descending: true, label: qsTr("Watched First")},
        {id: "newest", field: "insertion", descending: true, label: qsTr("Newest First")},
        {id: "oldest", field: "insertion", descending: false, label: qsTr("Oldest First")},
        {id: "title-asc", field: "title", descending: false, label: qsTr("Title A-Z")},
        {id: "title-desc", field: "title", descending: true, label: qsTr("Title Z-A")},
        {id: "artist-asc", field: "main_artist", descending: false, label: qsTr("Artist A-Z")},
        {id: "artist-desc", field: "main_artist", descending: true, label: qsTr("Artist Z-A")},
        {id: "album-asc", field: "album_title", descending: false, label: qsTr("Album A-Z")},
        {id: "album-desc", field: "album_title", descending: true, label: qsTr("Album Z-A")},
        {id: "track-asc", field: "track_number", descending: false, label: qsTr("Track Number Ascending")},
        {id: "track-desc", field: "track_number", descending: true, label: qsTr("Track Number Descending")},
        {id: "uri-asc", field: "uri", descending: false, label: qsTr("URI Ascending")},
        {id: "uri-desc", field: "uri", descending: true, label: qsTr("URI Descending")},
        {id: "disc-asc", field: "disc_number", descending: false, label: qsTr("Disc Number Ascending")},
        {id: "disc-desc", field: "disc_number", descending: true, label: qsTr("Disc Number Descending")}
    ]
    readonly property var options: extraOptions.concat(catalog.filter(option => fields.includes(option.field)))
    readonly property var selection: options.find(option => option.id === saved[scope])
        || options.find(option => option.id === defaultChoice) || options[0]
        || {id: "", field: "", descending: false}
    function load() {
        try {
            const value = ctx ? JSON.parse(ctx.settingValue(storageKey, "{}")) : {}
            saved = value && !Array.isArray(value) && typeof value === "object" ? value : {}
        } catch (error) { saved = {} }
    }
    function select(id) {
        if (!options.some(option => option.id === id)) return
        saved = Object.assign({}, saved, {[scope]: id})
        if (ctx) ctx.setSettingValue(storageKey, JSON.stringify(saved))
    }
    onCtxChanged: if (ready) load()
    Component.onCompleted: { load(); ready = true }
}
