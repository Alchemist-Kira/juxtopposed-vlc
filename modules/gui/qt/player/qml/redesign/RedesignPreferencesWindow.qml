// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as C
import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

Window {
    id: root
    title: qsTr("Settings — VLC Media Player")
    width: Math.min(theme.dp(1078), Screen.desktopAvailableWidth - theme.dp(40))
    height: Math.min(theme.dp(895), Screen.desktopAvailableHeight - theme.dp(60))
    minimumWidth: theme.dp(640); minimumHeight: theme.dp(440)
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    transientParent: MainCtx.intfMainWindow
    color: theme.background
    property real scaleFactor: VLCStyle.scale
    property bool lightTheme: !VLCStyle.palette.isDark
    property string category: "general"
    property string categoryTitle: qsTr("General")
    property bool advanced: false
    property string search: ""
    property int pendingTheme: 2
    property bool appearanceDirty: false
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme }
    RedesignPreferences { id: preferenceStore; ctx: MainCtx }
    RedesignPreferencesCatalog { id: specification }
    function begin() {
        preferenceStore.discard()
        searchField.clear()
        pendingTheme = MainCtx.colorScheme.scheme
        appearanceDirty = false
        visible = true
        raise(); requestActivate()
    }
    function cancel() { preferenceStore.discard(); visible = false }
    function save(closeAfter) {
        // Moving focus commits the text field currently being edited.
        content.forceActiveFocus()
        if (preferenceStore.save()) {
            if (appearanceDirty) MainCtx.colorScheme.setData(MainCtx.colorScheme.index(pendingTheme, 0), true, Qt.CheckStateRole)
            appearanceDirty = false
            if (closeAfter) visible = false
        }
    }
    onClosing: event => { event.accepted = false; cancel() }
    Connections {
        target: DialogsProvider
        function onShowRedesignPreferences() { if (!root.visible) root.begin(); else { root.raise(); root.requestActivate() } }
    }
    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.cancel()
        Rectangle {
            id: navigation
            width: theme.dp(250); anchors.top: parent.top; anchors.bottom: parent.bottom
            color: theme.panel
            C.TextField {
                id: searchField
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: theme.dp(20); height: theme.dp(34)
                placeholderText: qsTr("Search settings")
                color: theme.foreground; placeholderTextColor: theme.foreground
                font.pixelSize: theme.dp(14); selectByMouse: true
                background: Rectangle { color: theme.background; radius: theme.dp(4); border.color: searchField.activeFocus ? theme.accent : theme.border }
                onTextEdited: root.search = text
                onTextChanged: if (!text.length) root.search = ""
            }
            C.ScrollView {
                anchors.top: searchField.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.topMargin: theme.dp(18)
                clip: true
                Column {
                    width: navigation.width
                    Repeater {
                        model: [
                            {group: qsTr("App"), key: "general", title: qsTr("General"), icon: "settings"},
                            {key: "interface", title: qsTr("Interface"), icon: "video"},
                            {key: "privacy", title: qsTr("Privacy"), icon: "history"},
                            {key: "controls", title: qsTr("Controls"), icon: "play"},
                            {group: qsTr("Media"), key: "playback", title: qsTr("Playback"), icon: "play"},
                            {key: "video", title: qsTr("Video"), icon: "video"},
                            {key: "audio", title: qsTr("Audio"), icon: "audio"},
                            {key: "subtitles", title: qsTr("Subtitles"), icon: "subtitles"},
                            {key: "library", title: qsTr("Library"), icon: "folder"},
                            {group: qsTr("System"), key: "network", title: qsTr("Network"), icon: "network"},
                            {key: "performance", title: qsTr("Performance"), icon: "settings"},
                            {key: "recording", title: qsTr("Recording"), icon: "video"},
                            {key: "extensions", title: qsTr("Extensions"), icon: "add"} ]
                        delegate: Column {
                            required property var modelData
                            width: navigation.width
                            Text {
                                visible: !!modelData.group
                                height: visible ? theme.dp(42) : 0
                                leftPadding: theme.dp(22); topPadding: theme.dp(17)
                                text: modelData.group || ""; color: theme.foreground; font.pixelSize: theme.dp(12)
                            }
                            RedesignButton {
                                width: parent.width - theme.dp(20); x: theme.dp(10); height: theme.dp(40)
                                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                                caption: modelData.title; text: caption; iconName: modelData.icon
                                selected: root.category === modelData.key && !root.search.length
                                onClicked: {
                                    root.category = modelData.key; root.categoryTitle = modelData.title
                                    root.search = ""; searchField.clear(); root.advanced = false
                                    scroll.contentItem.contentY = 0
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            id: heading
            anchors.left: navigation.right; anchors.leftMargin: theme.dp(24)
            y: theme.dp(22)
            text: root.search.length ? qsTr("Search results") : root.categoryTitle
            color: theme.bright; font.pixelSize: theme.dp(18)
        }
        MouseArea {
            anchors.left: navigation.right; anchors.right: closeButton.left; anchors.top: parent.top; height: theme.dp(60)
            z: -1
            onPressed: root.startSystemMove()
        }
        RedesignButton {
            id: closeButton
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: theme.dp(12)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
            iconName: "close"; text: qsTr("Close settings")
            onClicked: root.cancel()
        }
        C.ScrollView {
            id: scroll
            anchors.top: parent.top; anchors.topMargin: theme.dp(68)
            anchors.left: navigation.right; anchors.right: parent.right; anchors.bottom: footer.top
            anchors.leftMargin: theme.dp(24); anchors.rightMargin: theme.dp(24)
            clip: true
            contentWidth: availableWidth
            Column {
                width: scroll.availableWidth
                spacing: theme.dp(6)
                ColumnLayout {
                    visible: root.category === "general" && !root.search.length
                    width: parent.width
                    spacing: theme.dp(16)
                    Text { text: qsTr("Appearance"); color: theme.bright; font.pixelSize: theme.dp(16); Layout.topMargin: theme.dp(8) }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: qsTr("Theme"); color: theme.foreground; font.pixelSize: theme.dp(14) }
                        C.ComboBox {
                            Layout.preferredWidth: theme.dp(320)
                            model: [qsTr("System"), qsTr("Light"), qsTr("Dark")]
                            currentIndex: root.pendingTheme
                            palette.button: theme.background; palette.buttonText: theme.foreground
                            palette.text: theme.foreground; palette.base: theme.field; palette.window: theme.panel
                            background: Rectangle { color: theme.background; radius: theme.dp(4); border.color: theme.border }
                            onActivated: { root.pendingTheme = currentIndex; root.appearanceDirty = true }
                        }
                        Item { width: theme.dp(26) }
                    }
                    RedesignPreferenceRow { Layout.fillWidth: true; backend: preferenceStore; optionName: "qt-accent-color"; label: qsTr("Accent color"); scaleFactor: root.scaleFactor; lightTheme: root.lightTheme }
                    RedesignPreferenceRow { Layout.fillWidth: true; backend: preferenceStore; optionName: "language"; label: qsTr("Language"); scaleFactor: root.scaleFactor; lightTheme: root.lightTheme }
                }
                Repeater {
                    model: root.search.length ? [] : specification.sections[root.category] || []
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        Text {
                            topPadding: theme.dp(24); bottomPadding: theme.dp(10)
                            text: modelData.title; color: theme.bright; font.pixelSize: theme.dp(16)
                        }
                        Repeater {
                            model: modelData.rows
                            delegate: RedesignPreferenceRow {
                                required property var modelData
                                width: parent.width
                                backend: preferenceStore; optionName: modelData[0]; label: modelData[1]
                                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                            }
                        }
                    }
                }
                RedesignButton {
                    visible: !root.search.length
                    width: parent.width; height: theme.dp(40)
                    scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                    caption: root.advanced ? qsTr("Hide Advanced Options") : qsTr("Advanced Options")
                    text: caption; selected: root.advanced
                    onClicked: root.advanced = !root.advanced
                }
                Repeater {
                    model: root.advanced || root.search.length ? preferenceStore.catalog(root.category, root.search) : []
                    delegate: RedesignPreferenceRow {
                        required property var modelData
                        width: parent.width
                        backend: preferenceStore; optionName: modelData.name
                        scaleFactor: root.scaleFactor; lightTheme: root.lightTheme
                    }
                }
                Item { width: 1; height: theme.dp(24) }
            }
        }
        Rectangle {
            id: footer
            anchors.left: navigation.right; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: theme.dp(76); color: theme.background
            Text {
                anchors.left: parent.left; anchors.right: actions.left; anchors.verticalCenter: parent.verticalCenter
                anchors.margins: theme.dp(24)
                text: preferenceStore.errorMessage || qsTr("Some changes take effect the next time VLC starts.")
                color: preferenceStore.errorMessage.length ? "#e56b6b" : theme.foreground
                font.pixelSize: theme.dp(12); wrapMode: Text.WordWrap
            }
            Row {
                id: actions
                anchors.right: parent.right; anchors.rightMargin: theme.dp(24); anchors.verticalCenter: parent.verticalCenter
                spacing: theme.dp(10)
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; caption: qsTr("Cancel"); text: caption; onClicked: root.cancel() }
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; caption: qsTr("Apply"); text: caption; enabled: preferenceStore.dirty || root.appearanceDirty; onClicked: root.save(false) }
                RedesignButton { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; caption: qsTr("Save"); text: caption; accent: true; onClicked: root.save(true) }
            }
        }
    }
}
