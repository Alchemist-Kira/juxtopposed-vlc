// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

QtObject {
    id: root
    property var ctx
    property var entries: []
    readonly property string storageKey: "Juxtopposed/library-visits"
    Component.onCompleted: {
        try {
            const saved = JSON.parse(ctx.settingValue(storageKey, "[]"))
            if (Array.isArray(saved)) entries = saved.filter(entry => entry && typeof entry.key === "string" && typeof entry.name === "string" && ["folders", "playlists"].includes(entry.kind) && Number.isFinite(entry.count) && entry.count > 0)
        } catch (error) { entries = [] }
    }
    function record(kind, key, name) {
        if (!key.length || !name.length || !["folders", "playlists"].includes(kind)) return
        const next = entries.filter(entry => entry.kind !== kind || entry.key !== key)
        const previous = entries.find(entry => entry.kind === kind && entry.key === key)
        next.push({kind: kind, key: key, name: name, count: previous ? previous.count + 1 : 1, last: Date.now()})
        next.sort((a, b) => b.count - a.count || b.last - a.last)
        entries = next.slice(0, 400)
        ctx.setSettingValue(storageKey, JSON.stringify(entries))
    }
    function ranked(kind, search) {
        const pattern = search.toLocaleLowerCase()
        return entries.filter(entry => entry.kind === kind && entry.name.toLocaleLowerCase().includes(pattern))
            .sort((a, b) => b.count - a.count || (b.last || 0) - (a.last || 0))
    }
}
