// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQml.Models

ColumnLayout {
    id: root
    property real scaleFactor: 1
    property bool lightTheme: false
    property var trackModel
    property string heading
    property bool allowDisable: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme }
    signal selectionRequested(int index, bool selected)
    signal disableRequested()
    spacing: theme.dp(4)
    Text { text: root.heading; color: theme.bright; font.pixelSize: theme.dp(14); Layout.bottomMargin: theme.dp(8) }
    RedesignButton {
        visible: root.allowDisable
        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
        caption: qsTr("None"); text: caption
        onClicked: root.disableRequested()
    }
    Repeater {
        id: choices
        model: root.trackModel
        Item {
            id: track
            required property int index
            required property string display
            required property bool checked
            Layout.fillWidth: true
            implicitHeight: root.theme.dp(36)
            RedesignButton {
                anchors.fill: parent
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                text: track.display; caption: track.display; iconName: track.checked ? "check" : ""; selected: track.checked
                onClicked: root.selectionRequested(track.index, !track.checked)
            }
        }
    }
    Text { visible: choices.count === 0; text: qsTr("No tracks available"); color: theme.foreground; font.pixelSize: theme.dp(13) }
}
