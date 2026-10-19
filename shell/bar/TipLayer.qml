import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../components"

/**
 * The menu bar's tooltips on one screen (core/Menus says which): a bubble of
 * glass, its pointer up at the extra, that pops out of the bar's lower edge
 * with the menus' motion (GlassMorph) and, sliding along the bar, reshapes
 * onto the next extra. A strip under the bar that never takes the pointer,
 * mapped only while a tooltip shows.
 */
PanelWindow {
    id: layer

    required property ShellScreen modelData
    screen: modelData

    readonly property bool wanted: Menus.tipShown && Menus.tipScreen === modelData.name
    /** What the bubble says, kept while it melts back into the bar. */
    property string text: ""
    onWantedChanged: if (wanted && Menus.tip.length) text = Menus.tip
    Connections {
        target: Menus
        function onTipChanged() {
            if (layer.wanted && Menus.tip.length)
                layer.text = Menus.tip;
        }
    }

    anchors { top: true; left: true; right: true }
    margins.top: Tokens.bar.height
    implicitHeight: 64
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-tip"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    visible: wanted || morph.active

    readonly property real padX: Tokens.space.l
    // The pointer always shows: the bubble hangs low enough that its tip
    // clears the arrow of a pointer resting on the extra, as macOS's do.
    readonly property real drop: Tokens.menu.gap + Tokens.space.xs
    readonly property real padY: Tokens.space.s
    TextMetrics {
        id: metrics
        font.family: Tokens.family
        font.pixelSize: Tokens.type.subheadline.size
        text: layer.text
    }
    /** The bubble and its pointer, centred under the extra and kept on screen. */
    readonly property rect bubble: {
        const w = Math.ceil(metrics.advanceWidth) + 2 * padX;
        const h = Math.ceil(metrics.height) + 2 * padY + morph.tailLength;
        const cx = Menus.tipX + Menus.tipWidth / 2;
        const x = Math.max(Tokens.menu.edgeMargin, Math.min(modelData.width - w - Tokens.menu.edgeMargin, cx - w / 2));
        return Qt.rect(Math.round(x), drop, w, h);
    }

    GlassBackdrop {
        id: tipBackdrop
        screen: layer.modelData
        origin: Qt.point(0, Tokens.bar.height)
        region: Qt.rect(layer.bubble.x, layer.bubble.y + Tokens.bar.height, layer.bubble.width, layer.bubble.height)
    }

    GlassMorph {
        id: morph
        anchors.fill: parent
        open: layer.wanted
        fromRect: Qt.rect(Menus.tipX, 0, Menus.tipWidth, 4)
        toRect: layer.bubble
        tailX: Menus.tipX + Menus.tipWidth / 2
        tailSide: -1
        panelRadius: 10
        backdrop: tipBackdrop

        Text {
            x: layer.padX
            y: layer.padY + morph.tailLength
            text: layer.text
            color: Tokens.label
            font: metrics.font
        }
    }
}
