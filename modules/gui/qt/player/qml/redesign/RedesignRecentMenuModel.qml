// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import VLC.MediaLibrary

MLRecentMediaModel {
    ml: MediaLib
    limit: 10
    function playMedia(mediaId) { MediaLib.addAndPlay(mediaId) }
}
