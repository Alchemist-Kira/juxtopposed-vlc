// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style

RedesignNetworkDialog {
    id: root
    scaleFactor: VLCStyle.scale
    lightTheme: !VLCStyle.palette.isDark
    accentColor: MainCtx.redesignAccent
    onSaveRequested: (urls, name) => streams.openStreams(urls, name)
    MLUrlModel {
        id: streams
        ml: MediaLib
        onStreamsOpened: success => root.finish(success)
    }
}
