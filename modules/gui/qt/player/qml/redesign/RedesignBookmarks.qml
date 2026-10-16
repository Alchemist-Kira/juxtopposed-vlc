// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import VLC.Player
import VLC.MediaLibrary
import VLC.Dialogs
import VLC.MainInterface

RedesignBookmarksView {
    id: root
    Binding {
        target: MainCtx; property: "useGlobalShortcuts"; value: false
        when: root.editing
        restoreMode: Binding.RestoreBindingOrValue
    }
    bookmarkModel: DialogsProvider.bookmarkModel
    canAdd: Player.isStarted
    onAddRequested: DialogsProvider.addBookmark()
    onRemoveRequested: index => bookmarkModel.remove([bookmarkModel.index(index, 0)])
    onActivateRequested: index => bookmarkModel.select(bookmarkModel.index(index, 0))
    onRenameRequested: (index, name) => bookmarkModel.setData(bookmarkModel.index(index, 0), name, Qt.EditRole)
}
