pragma Singleton

import QtQuick
import Quickshell
import "accent.mjs" as Accent

/**
 * The accent color taken from the wallpaper (see accent.mjs for how it's
 * chosen). `source` is the image path; shell.qml points it at the main
 * screen's wallpaper, since this singleton can't reach the Wallpaper service
 * without an import cycle. `tone` is null while there's no image or the image
 * is too grey, and Tokens then keeps the system blue.
 */
Singleton {
    id: root

    property string source: ""

    readonly property var tone: {
        const colors = [];
        for (const c of quantizer.colors)
            colors.push({ r: c.r, g: c.g, b: c.b });
        const t = Accent.wallpaperAccent(colors, Settings.dark);
        return t ? Qt.rgba(t.r, t.g, t.b, 1) : null;
    }

    ColorQuantizer {
        id: quantizer
        source: root.source.length ? "file://" + root.source : ""
        // 2^5 swatches of equal share; the hue doesn't need more pixels.
        depth: 5
        rescaleSize: 96
    }
}
