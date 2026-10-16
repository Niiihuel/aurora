import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"

/**
 * The window switcher (Alt+Tab), after macOS's app switcher in Tahoe's liquid
 * glass: a glass panel in the middle of the focused screen with a card per
 * window — a live thumbnail, the app's icon on its lower edge, the title —
 * most recently used first, the previous window chosen on open.
 *
 * The selection is a lens of glass that slides from card to card on a
 * snappy spring and stretches with its speed, like a drop of liquid moving.
 *
 * From niri's switcher: previews are large and keep each window's shape
 * (all scaled down together when they don't fit), long titles fade out
 * instead of being cut, a quick Alt+Tab tap switches without the panel ever
 * appearing (it waits `openDelay`), and Alt+` walks only the current app's
 * windows.
 *
 * Hyprland owns the keys and tells aurora through global shortcuts, so no
 * keyboard grab is needed (one couldn't see Alt's release): Alt+Tab
 * (`aurora:switcherNext`) opens or advances, Alt+Shift+Tab goes back,
 * releasing Alt (`aurora:switcherCommit`) focuses the choice, Alt+Escape
 * (`aurora:switcherCancel`) closes. A click on a card chooses it too.
 */
PanelWindow {
    id: root

    /** A switch is in progress (Alt held); `shown` once the panel is up. */
    property bool active: false
    property bool shown: false
    property int selected: 0
    /** The windows at the moment it opened, most recent first. */
    property var windows: []
    /** Like niri: a quick tap switches without flashing the panel. */
    readonly property int openDelay: 150

    Timer {
        id: openTimer
        interval: root.openDelay
        onTriggered: if (root.active) root.shown = true
    }

    function collect() {
        const list = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.address || o.hidden || o.mapped === false || !t.wayland)
                continue;
            const aspect = o.size && o.size[1] > 0 ? o.size[0] / o.size[1] : 1.6;
            list.push({ toplevel: t, address: o.address, title: o.title || o.class || "", appClass: o.class || "", order: o.focusHistoryID ?? 99, aspect });
        }
        list.sort((a, b) => a.order - b.order);
        return list;
    }

    /** Alt+Tab (`sameApp` false) or Alt+` (only the current window's app). */
    function step(direction, sameApp) {
        if (!active) {
            Hyprland.refreshToplevels();
            let list = collect();
            if (sameApp && list.length)
                list = list.filter(w => w.appClass === list[0].appClass);
            if (list.length < 2)
                return;
            windows = list;
            selected = direction > 0 ? 1 : list.length - 1;
            active = true;
            openTimer.restart();
            return;
        }
        selected = (selected + direction + windows.length) % windows.length;
    }

    function commit() {
        if (!active)
            return;
        const w = windows[selected];
        active = false;
        shown = false;
        openTimer.stop();
        if (w)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${w.address}" })`);
    }

    function cancel() {
        active = false;
        shown = false;
        openTimer.stop();
    }

    GlobalShortcut { appid: "aurora"; name: "switcherNext"; description: "Switch to the next window"; onPressed: root.step(1, false) }
    GlobalShortcut { appid: "aurora"; name: "switcherPrevious"; description: "Switch to the previous window"; onPressed: root.step(-1, false) }
    GlobalShortcut { appid: "aurora"; name: "switcherNextApp"; description: "Switch to the next window of this app"; onPressed: root.step(1, true) }
    // Bound to Alt's release, so Hyprland sends it as a release.
    GlobalShortcut { appid: "aurora"; name: "switcherCommit"; description: "Focus the chosen window"; onPressed: root.commit(); onReleased: root.commit() }
    GlobalShortcut { appid: "aurora"; name: "switcherCancel"; description: "Close the window switcher"; onPressed: root.cancel() }

    SpringValue {
        id: openness
        to: root.shown ? 1 : 0
        preset: root.shown ? Motion.smooth : Motion.dismiss
        // Gone: drop the cards, and with them their window captures.
        onSettledChanged: if (settled && !root.shown && !root.active) root.windows = []
    }

    screen: {
        const focused = Hyprland.focusedMonitor;
        for (const s of Quickshell.screens)
            if (focused && s.name === focused.name)
                return s;
        return Quickshell.screens[0];
    }

    // --- Size: cards shrink to fit when there are many windows ----------------------------

    readonly property real pad: 18
    readonly property real gap: 14
    readonly property real maxWidth: screen.width * 0.9
    /** Previews keep each window's shape at one height; all shrink together to fit. */
    readonly property real baseHeight: Math.min(240, Math.round(screen.height * 0.26))
    readonly property real aspectSum: windows.reduce((s, w) => s + w.aspect, 0)
    readonly property real thumbHeight: {
        const room = maxWidth - 2 * pad - Math.max(0, windows.length - 1) * gap;
        return Math.floor(Math.min(baseHeight, room / Math.max(0.1, aspectSum)));
    }
    readonly property real cardHeight: thumbHeight + 52
    /** Each card's x inside the row. */
    readonly property var offsets: {
        const xs = [];
        let x = 0;
        for (const w of windows) {
            xs.push(x);
            x += w.aspect * thumbHeight + gap;
        }
        return xs;
    }
    function cardWidth(i) {
        return windows[i] ? windows[i].aspect * thumbHeight : 0;
    }

    visible: shown || !openness.settled
    implicitWidth: panel.width + 40
    implicitHeight: panel.height + 40
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    GlassBackdrop {
        id: switcherBackdrop
        screen: root.screen
        // Unanchored layers are centred by the compositor.
        origin: Qt.point((root.screen.width - root.implicitWidth) / 2, (root.screen.height - root.implicitHeight) / 2)
        region: Qt.rect(origin.x + panel.x, origin.y + panel.y, panel.width, panel.height)
    }

    Item {
        id: panel
        x: 20
        y: 20
        width: 2 * root.pad + root.aspectSum * root.thumbHeight + Math.max(0, root.windows.length - 1) * root.gap
        height: 2 * root.pad + root.cardHeight
        opacity: openness.value
        scale: 0.94 + 0.06 * openness.value

        Glass {
            anchors.fill: parent
            backdrop: switcherBackdrop
            material: Tokens.glass.regular
            radius: 30
            track: [panel.scale]
        }

        // The selection lens: slides on a spring and stretches with its speed.
        SpringValue {
            id: lensX
            to: root.pad + (root.offsets[root.selected] ?? 0)
            preset: Motion.snappy
            Component.onCompleted: snap(to)
        }
        Connections {
            target: root
            function onShownChanged() {
                if (root.shown)
                    lensX.snap(root.pad + (root.offsets[root.selected] ?? 0));
            }
        }
        Glass {
            id: lens
            readonly property real stretch: Math.min(40, Math.abs(lensX.velocity) * 0.025)
            x: lensX.value - 6 - stretch / 2
            y: root.pad - 6
            width: root.cardWidth(root.selected) + 12 + stretch
            height: root.cardHeight + 12 - stretch * 0.3
            backdrop: switcherBackdrop
            material: Tokens.glass.lens
            radius: 20
            shadow: false
            track: [x, width, height, panel.scale]
        }

        Row {
            x: root.pad
            y: root.pad
            spacing: root.gap

            Repeater {
                model: root.windows
                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selected
                    width: root.cardWidth(index)
                    height: root.cardHeight

                    ClippingRectangle {
                        id: thumb
                        width: parent.width
                        height: root.thumbHeight
                        radius: 12
                        color: Tokens.toggleOff

                        ScreencopyView {
                            id: view
                            anchors.centerIn: parent
                            // Keep the window's own aspect inside the thumbnail.
                            readonly property real aspect: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6
                            width: Math.min(parent.width, parent.height * aspect)
                            height: width / aspect
                            captureSource: card.modelData.toplevel.wayland
                            // Live: every new frame of the window, so a playing video
                            // stays as smooth as the screen. Live captures redraw at
                            // the display's rate (see GlassBackdrop), fine for an
                            // overlay that is open for a second.
                            live: root.shown
                        }
                    }

                    Image {
                        id: appIcon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.thumbHeight - 18
                        width: 36
                        height: 36
                        sourceSize: Qt.size(72, 72)
                        source: {
                            const entry = DesktopEntries.heuristicLookup(card.modelData.appClass);
                            return entry ? Apps.iconFor(entry) : "";
                        }
                        visible: status === Image.Ready
                    }

                    // The title, centred; a long one fades out at the end (niri) instead of "…".
                    Item {
                        id: titleBox
                        readonly property bool overflow: title.implicitWidth > width
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        height: title.implicitHeight
                        clip: true
                        layer.enabled: overflow
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: fade
                        }

                        Text {
                            id: title
                            x: titleBox.overflow ? 0 : (titleBox.width - implicitWidth) / 2
                            text: card.modelData.title
                            color: card.current ? Tokens.label : Tokens.secondaryLabel
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.callout.size
                            font.weight: card.current ? Font.DemiBold : Font.Normal
                        }
                    }
                    Rectangle {
                        id: fade
                        anchors.fill: titleBox
                        visible: false
                        layer.enabled: true
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "white" }
                            GradientStop { position: Math.max(0, 1 - 32 / Math.max(1, titleBox.width)); color: "white" }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        // Only a real move picks: a card appearing under a resting pointer mustn't.
                        onPositionChanged: root.selected = card.index
                        onClicked: {
                            root.selected = card.index;
                            root.commit();
                        }
                    }
                }
            }
        }
    }
}
