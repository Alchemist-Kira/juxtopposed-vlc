// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C

C.Pane {
    id: root
    property real scaleFactor: 1
    property color accentColor: "#d37918"
    property bool lightTheme: false
    property var statistics: ({})
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    padding: theme.dp(16)
    implicitWidth: theme.dp(330)
    background: Rectangle {
        color: Qt.rgba(root.theme.panel.r, root.theme.panel.g, root.theme.panel.b, 0.94)
        radius: root.theme.dp(8); border.color: root.theme.border
    }
    contentItem: C.ScrollView {
        implicitHeight: rows.implicitHeight
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: rows
            width: parent.width
            spacing: root.theme.dp(6)
            Text {
                text: qsTr("Playback Statistics"); color: root.theme.bright
                font.pixelSize: root.theme.dp(15)
                Layout.bottomMargin: root.theme.dp(6)
            }
            Repeater {
                model: [
                    {key: "inputBitrate", label: qsTr("Input bitrate"), suffix: " kb/s", decimals: 0},
                    {key: "streamBitrate", label: qsTr("Stream bitrate"), suffix: " kb/s", decimals: 0},
                    {key: "decodedVideo", label: qsTr("Decoded video frames")},
                    {key: "displayedPictures", label: qsTr("Displayed video frames")},
                    {key: "latePictures", label: qsTr("Late video frames")},
                    {key: "lostPictures", label: qsTr("Lost video frames")},
                    {key: "decodedAudio", label: qsTr("Decoded audio blocks")},
                    {key: "playedAudioBuffers", label: qsTr("Played audio blocks")},
                    {key: "lostAudioBuffers", label: qsTr("Lost audio blocks")},
                    {key: "corruptedPackets", label: qsTr("Corrupted packets")}
                ]
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: root.theme.dp(12)
                    Text {
                        Layout.fillWidth: true
                        text: parent.modelData.label; color: root.theme.foreground
                        font.pixelSize: root.theme.dp(12); wrapMode: Text.WordWrap
                    }
                    Text {
                        objectName: "statistic_" + parent.modelData.key
                        text: root.statistics[parent.modelData.key] === undefined ? "—"
                            : Number(root.statistics[parent.modelData.key]).toLocaleString(Qt.locale(), 'f', parent.modelData.decimals || 0) + (parent.modelData.suffix || "")
                        color: root.theme.bright; font.pixelSize: root.theme.dp(12)
                    }
                }
            }
        }
    }
}
