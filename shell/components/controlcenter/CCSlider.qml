import QtQuick
import "../../core"
import ".."
import "../menu"

/**
 * Control Center's slider: aurora's own MenuSlider (accent fill and the
 * liquid glass knob that lifts into a lens while dragged) with a small glyph
 * at each end for the low and the high end, as in macOS Tahoe's Display and
 * Sound modules. Emits `moved(v)` (0–1); the owner applies it and feeds
 * `value` back.
 */
Item {
    id: root

    property real value: 0
    property Item backdrop: null
    property var lowGlyph: []
    property var highGlyph: []
    signal moved(real v)

    implicitHeight: 32

    Icon {
        id: low
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        glyph: root.lowGlyph
        size: root.lowGlyph.length ? 12 : 0
        color: Tokens.secondaryLabel
        dimColor: Tokens.tertiaryLabel
    }

    Icon {
        id: high
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        glyph: root.highGlyph
        size: root.highGlyph.length ? 15 : 0
        color: Tokens.secondaryLabel
        dimColor: Tokens.tertiaryLabel
    }

    MenuSlider {
        anchors.left: low.right
        anchors.right: high.left
        // MenuSlider keeps its own inset; without end glyphs, reach the edges.
        anchors.leftMargin: root.lowGlyph.length ? 0 : -Tokens.menu.itemInset
        anchors.rightMargin: root.highGlyph.length ? 0 : -Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        backdrop: root.backdrop
        value: root.value
        onMoved: v => root.moved(v)
    }
}
