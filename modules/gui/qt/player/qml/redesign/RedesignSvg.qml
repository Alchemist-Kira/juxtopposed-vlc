// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

Image {
    property string svg
    sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    // Standalone QML previews do not have VLC's image providers.
    source: svg.length ? ((typeof redesignSvgImages !== "undefined" && redesignSvgImages
        ? "image://svgcolor/?_res_SVG=" : "data:image/svg+xml;utf8,") + encodeURIComponent(svg)) : ""
}
