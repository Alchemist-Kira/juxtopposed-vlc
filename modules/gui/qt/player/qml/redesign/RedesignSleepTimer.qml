// SPDX-License-Identifier: GPL-2.0-or-later
import QtQml

QtObject {
    id: root
    property int selectedMinutes: 0
    readonly property int minutes: clock.running ? selectedMinutes : 0
    signal triggered()
    readonly property Timer clock: Timer { onTriggered: root.triggered() }

    function start(minutes) {
        if (!Number.isInteger(minutes) || minutes < 0 || minutes > 35791) return false
        clock.stop()
        selectedMinutes = minutes
        if (minutes > 0) {
            clock.interval = minutes * 60000
            clock.start()
        }
        return true
    }
}
