// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts

C.ComboBox {
    id: root
    property real scaleFactor: 1
    property bool lightTheme: false
    property bool showCurvePreviews: false
    property real choiceHeight: 34
    property var labelOverrides: ({})
    function labelAt(index) { const text = textAt(index); return labelOverrides[text] || text }
    signal aboutToOpen()
    property color accentColor: "#d37918"
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }
    implicitHeight: theme.dp(34)
    font.pixelSize: theme.dp(14)
    leftPadding: theme.dp(14); rightPadding: theme.dp(40)
    contentItem: Text {
        text: root.displayText; font: root.font
        color: root.theme.foreground
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    background: Rectangle {
        radius: root.theme.dp(4); color: root.theme.background
        border.color: root.visualFocus ? root.theme.accent : root.theme.field
    }
    indicator: RedesignIcon {
        name: "chevron-down"; color: root.theme.foreground
        width: root.theme.dp(20); height: width
        x: root.width - width - root.theme.dp(14); y: (root.height - height) / 2
    }
    delegate: C.ItemDelegate {
        required property int index
        width: ListView.view.width
        implicitHeight: root.theme.dp(root.choiceHeight)
        text: root.labelAt(index)
        highlighted: root.highlightedIndex === index
        contentItem: RowLayout {
            spacing: root.theme.dp(10)
            Image {
                readonly property var curve: root.model && root.model[index] ? root.model[index].curve || [] : []
                readonly property color fillColor: root.theme.accent
                readonly property color lineColor: root.theme.foreground
                Layout.preferredWidth: root.theme.dp(24); Layout.preferredHeight: root.theme.dp(18)
                visible: root.showCurvePreviews && curve.length > 0
                sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                source: {
                    if (curve.length < 2 || width <= 0 || height <= 0) return ""
                    const middle = height / 2
                    let path = "M0 " + middle
                    for (let i = 0; i < curve.length; ++i)
                        path += " L" + (i * width / (curve.length - 1)) + " " + (middle - Number(curve[i]) * middle / 20)
                    path += " L" + width + " " + middle + " Z"
                    return "data:image/svg+xml;utf8," + encodeURIComponent(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">'
                        + '<path d="' + path + '" fill="' + fillColor + '"/>'
                        + '<path d="M0 ' + middle + ' H' + width + '" fill="none" stroke="' + lineColor + '" stroke-width="1"/></svg>')
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.labelAt(index); font: root.font; color: root.theme.foreground
                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
            }
            Item {
                Layout.preferredWidth: root.theme.dp(20); Layout.preferredHeight: root.theme.dp(20)
                visible: root.showCurvePreviews && index === root.currentIndex
                RedesignIcon { anchors.fill: parent; name: "check"; color: root.theme.accent }
            }
        }
        background: Rectangle { radius: root.theme.dp(3); color: parent.highlighted ? root.theme.hover : "transparent" }
    }
    popup: C.Popup {
        onAboutToShow: root.aboutToOpen()
        y: root.height + root.theme.dp(4)
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, root.theme.dp(300))
        padding: root.theme.dp(4)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            C.ScrollIndicator.vertical: C.ScrollIndicator { }
        }
        background: Rectangle { color: root.theme.panel; radius: root.theme.dp(6); border.color: root.theme.border }
    }
}
