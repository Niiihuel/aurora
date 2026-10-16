import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../components"
import "../menus"

/**
 * Where the menu bar's menus live on one screen, and how they move.
 *
 * Motion, from Apple's Liquid Glass (WWDC25 "Meet Liquid Glass", studied frame
 * by frame): a menu doesn't fade in, it materializes out of what you clicked.
 * The glass leaves the menu bar item as a small clear drop that lenses what's
 * behind it, swells (round first, then into the menu's rounded rectangle) on
 * a slightly bouncy spring, gains its veil as it forms, and the content
 * focuses in from a blur once the shape is more than half formed. Closing goes
 * the other way without bounce: the menu shrinks evenly into a drop while its
 * content blurs out, and the drop then melts into the item. Moving to another menu
 * (pointer tracking or ←/→) slides and stretches the same glass to the new
 * menu while its content focuses in.
 *
 * The layer covers the screen *below* the bar, so the bar always gets its
 * own clicks and hover (a second click on the open item closes its menu, a
 * click on another item or moving onto it switches). The glass therefore
 * emerges from the bar's lower edge under the item and melts back into it.
 * A press anywhere else closes the menu. While open it takes the
 * keyboard: ↑/↓ move the highlight, ←/→ switch to the neighbouring menu,
 * Return chooses, Esc closes.
 */
PanelWindow {
    id: menuLayer

    required property ShellScreen modelData
    screen: modelData

    readonly property bool wanted: Menus.isOpen && Menus.screen === modelData.name
    /** Last opened menu, kept while the close animation plays. */
    property string shownId: ""

    anchors { top: true; left: true; right: true; bottom: true }
    // Below the bar: an input mask leaving the bar strip out didn't reach
    // the compositor, so the layer swallowed every click meant for the bar.
    margins.top: Tokens.bar.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-menu"
    // Hyprland hands the pointer to a layer that takes the keyboard when it
    // maps (or turns Exclusive), even with the cursor over the bar, so a
    // second click on the item went nowhere. Grabbing Exclusive for a moment
    // and then dropping to OnDemand keeps the keyboard here and makes
    // Hyprland re-pick the pointer target (simulateMouseMovement). Staying
    // Exclusive isn't an option: then every click goes to this layer.
    WlrLayershell.keyboardFocus: !wanted ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    property bool grabbing: false
    onWantedChanged: if (wanted) {
        grabbing = true;
        grabRelease.restart();
    }
    Timer {
        id: grabRelease
        interval: 60
        onTriggered: menuLayer.grabbing = false
    }
    // Stay mapped from the first open until the glass is back in the item.
    // `wanted || !settled` hid the window for one frame at the start of a
    // close (springs still resting at the menu), which dropped the glass
    // textures and made the menu flash and jump.
    visible: wanted || shownId.length > 0

    function componentFor(id) {
        switch (id) {
        case "sound": return soundMenu;
        case "network": return networkMenu;
        case "bluetooth": return bluetoothMenu;
        case "battery": return batteryMenu;
        case "system": return systemMenu;
        case "controlCenter": return controlCenterMenu;
        case "notifications": return notificationCenter;
        default: return null;
        }
    }

    // --- Geometry --------------------------------------------------------------

    /**
     * Where the glass comes from and returns to: a sliver along the bar's
     * lower edge under the item (layer coordinates start at that edge).
     */
    readonly property rect itemRect: Qt.rect(Menus.anchorX, 0, Menus.anchorWidth, 4)

    readonly property real panelWidth: loader.item ? loader.item.implicitWidth : 0
    readonly property real panelHeight: loader.item ? loader.item.implicitHeight : 0
    /** Where the menu sits once open: under its item, pulled in from the screen edge. */
    readonly property rect panelRect: Qt.rect(
        // The screen's width, not the window's: a hidden layer has no size yet
        // when the first menu opens.
        Math.max(Tokens.menu.edgeMargin, Math.min(Menus.anchorX, modelData.width - panelWidth - Tokens.menu.edgeMargin)),
        Tokens.menu.gap, panelWidth, panelHeight)

    /** True during the drop beat of a fresh pop. */
    property bool dropping: false
    readonly property var openPreset: dropping ? Motion.menuDrop : Motion.menuOpen

    /** True once a closing menu has shrunk to its drop and melts into the item. */
    property bool merging: false
    readonly property var closePreset: merging ? Motion.menuMerge : Motion.menuClose

    SpringValue { id: sx; preset: menuLayer.wanted ? menuLayer.openPreset : menuLayer.closePreset; epsilon: 0.05 }
    SpringValue { id: sy; preset: menuLayer.wanted ? menuLayer.openPreset : menuLayer.closePreset; epsilon: 0.05 }
    SpringValue { id: sw; preset: menuLayer.wanted ? menuLayer.openPreset : menuLayer.closePreset; epsilon: 0.05 }
    SpringValue { id: sh; preset: menuLayer.wanted ? menuLayer.openPreset : menuLayer.closePreset; epsilon: 0.05 }

    readonly property bool settled: sx.settled && sy.settled && sw.settled && sh.settled

    /** Height of the last open menu, for measuring progress on the way back. */
    property real openHeight: 1

    /**
     * 0 at the item, 1 at the full menu (overshoots a little): drives the
     * corner shape, the bloom and the content's focus.
     */
    readonly property real progress: Math.max(0, (sh.value - itemRect.height) / Math.max(1, openHeight - itemRect.height))

    /**
     * The drop a menu leaves the item as: a circle under the item's centre,
     * about 45% of the menu's shorter side.
     */
    readonly property rect dropRect: {
        const d = Math.max(28, Math.min(80, 0.45 * Math.min(panelWidth, panelHeight)));
        const cx = itemRect.x + itemRect.width / 2;
        return Qt.rect(cx - d / 2, -d * 0.25, d, d);
    }

    Timer {
        id: dropTimer
        interval: Motion.menuPhases.dropHold * 1000
        onTriggered: {
            menuLayer.dropping = false;
            menuLayer.aim(false);
        }
    }

    Timer {
        id: mergeTimer
        interval: Motion.menuCloseHold * 1000
        onTriggered: {
            menuLayer.merging = true;
            menuLayer.aim(false);
        }
    }

    function aim(fresh) {
        const from = itemRect;
        if (wanted) {
            merging = false;
            mergeTimer.stop();
        }
        if (fresh && wanted) {
            dropping = true;
            dropTimer.restart();
        }
        const to = !wanted ? (merging ? itemRect : dropRect) : dropping ? dropRect : panelRect;
        if (wanted)
            openHeight = Math.max(1, panelRect.height);
        if (fresh) {
            sx.snap(from.x); sy.snap(from.y); sw.snap(from.width); sh.snap(from.height);
        }
        sx.to = to.x; sy.to = to.y; sw.to = to.width; sh.to = to.height;
    }

    Connections {
        target: Menus
        function onActiveChanged() {
            if (!Menus.active.length || Menus.screen !== menuLayer.modelData.name) {
                menuLayer.dropping = false;
                dropTimer.stop();
                menuLayer.merging = false;
                mergeTimer.restart();
                menuLayer.aim(false);
                return;
            }
            const fresh = menuLayer.shownId.length === 0;
            const switching = !fresh && menuLayer.shownId !== Menus.active;
            menuLayer.shownId = Menus.active;
            if (switching)
                focusIn.snap(0);
            if (fresh) {
                menuLayer.clock = 0;
                popClock.restart();
            }
            // Let the new menu lay out before measuring where the glass goes.
            Qt.callLater(() => menuLayer.aim(fresh));
        }
    }
    // Content that resizes while open (a network list filling in) reshapes the glass.
    onPanelRectChanged: if (wanted) aim(false)
    onSettledChanged: if (settled && !wanted && merging) shownId = ""

    SpringValue {
        id: carrier
        to: loader.item && loader.item.bare ? 0 : 1
        preset: Motion.smooth
    }

    /** The content's focus after a switch between menus. */
    SpringValue { id: focusIn; to: 1; preset: Motion.snappy }

    /**
     * Seconds since a menu started popping out of the bar. The bloom, the
     * shape and the content's focus follow it, like Apple's pop, while the
     * size rides the spring; closing goes by size instead (`progress`).
     */
    property real clock: Motion.menuPhases.total
    NumberAnimation {
        id: popClock
        target: menuLayer
        property: "clock"
        from: 0
        to: Motion.menuPhases.total
        duration: Motion.menuPhases.total * 1000
    }

    function span(t, a, b) {
        return Math.max(0, Math.min(1, (t - a) / (b - a)));
    }
    readonly property var phase: Motion.menuPhases
    /** 0–1 milky bloom: up to its peak, then clearing. */
    readonly property real bloom: wanted
        ? (clock < phase.bloomPeak ? span(clock, 0, phase.bloomPeak) : 1 - span(clock, phase.bloomPeak, phase.bloomEnd))
        : Math.max(0, Math.min(1, 1 - progress))
    /** 0 = round drop, 1 = the menu's corners. */
    // Closing loses the menu's corners at once, like Apple's: rounder by
    // 33 ms, an egg by ~70 ms.
    readonly property real shaped: wanted ? span(clock, phase.shapeStart, phase.shapeEnd) : span(progress, 0.8, 0.98)
    /** 0 = blurred out, 1 = sharp and opaque. */
    // Closing blurs the content out early, as the menu starts to shrink.
    readonly property real focused: wanted ? span(clock, phase.focusStart, phase.focusEnd) : span(progress, 0.68, 0.98)

    // --- Scene -------------------------------------------------------------------

    MouseArea {
        anchors.fill: parent
        onPressed: Menus.close()
    }

    GlassBackdrop {
        id: menuBackdrop
        screen: menuLayer.modelData
        origin: Qt.point(0, Tokens.bar.height)
        region: Qt.rect(menuLayer.panelRect.x, menuLayer.panelRect.y + Tokens.bar.height, menuLayer.panelWidth, menuLayer.panelHeight)
    }

    FocusScope {
        anchors.fill: parent
        focus: menuLayer.wanted

        Keys.onPressed: event => {
            const panel = loader.item;
            if (event.key === Qt.Key_Escape) {
                // A panel with levels (Control Center) steps back first.
                if (!(panel && panel.back && panel.back()))
                    Menus.close();
            }
            else if (event.key === Qt.Key_Down && panel)
                panel.move(1);
            else if (event.key === Qt.Key_Up && panel)
                panel.move(-1);
            else if (event.key === Qt.Key_Left)
                Menus.step(-1);
            else if (event.key === Qt.Key_Right)
                Menus.step(1);
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && panel)
                panel.activate();
            else
                return;
            event.accepted = true;
        }

        // The one glass shape that morphs between the item and the menu.
        Glass {
            id: glass
            x: sx.value
            y: sy.value
            width: Math.max(1, sw.value)
            height: Math.max(1, sh.value)
            visible: menuLayer.shownId.length > 0
            backdrop: menuBackdrop
            material: Tokens.glass.regular
            // Round as a drop at first, the menu's corners once it has formed.
            radius: {
                const drop = Math.min(width, height) / 2;
                const corner = (loader.item && loader.item.panelRadius) || Tokens.radius.menu;
                return drop + (corner - drop) * menuLayer.shaped;
            }
            // A faint light, not a white drop: the glass shows its lensing
            // first and gains its veil as it forms.
            bloom: menuLayer.bloom
            // Closing keeps the veil: Apple's returning drop is the densest
            // glass of the whole motion.
            presence: menuLayer.wanted ? 0.25 + 0.75 * menuLayer.shaped : 1
            // Closing: the drop reaches the item whole and only then melts into
            // it (Apple's drop merges into the bar as a bump that flattens).
            // A bare panel (Control Center's grid) has no glass of its own
            // behind its modules: this glass carries the pop and hands over to
            // them as they focus in (and takes them back on the way out).
            opacity: (menuLayer.wanted ? 1 : menuLayer.span(menuLayer.progress, 0.0, 0.12))
                * Math.max(1 - content.reveal, carrier.value)
            track: [sx.value, sy.value, sw.value, sh.value]
        }

        // Content is laid out at its final place and revealed by the glass.
        Item {
            id: clipper
            x: glass.x
            y: glass.y
            width: glass.width
            height: glass.height
            // The glass reveals the content while it morphs. At rest nothing
            // clips: a pressed module grows past the panel's edge (it lifts).
            clip: !(menuLayer.wanted && menuLayer.settled)

            // Clicks inside the menu must not reach the close-on-press area.
            MouseArea { anchors.fill: parent }

            Item {
                id: content
                x: menuLayer.panelRect.x - clipper.x
                y: menuLayer.panelRect.y - clipper.y
                width: menuLayer.panelWidth
                height: menuLayer.panelHeight

                readonly property real reveal: Math.min(focusIn.value, menuLayer.focused)
                opacity: reveal
                // The layer only exists for the blur while the content focuses
                // in or out. At rest it must be off: a layer is a snapshot that
                // doesn't hear its glass children's backdrop changing, so glass
                // inside it (Control Center's modules, slider knobs) froze on
                // whatever was behind when it opened.
                layer.enabled: menuLayer.shownId.length > 0 && reveal < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 1 - content.reveal
                }

                Loader {
                    id: loader
                    sourceComponent: menuLayer.componentFor(menuLayer.shownId)
                }
                // Where the panel sits moves after it's created (its width is
                // only known then): glass inside it re-maps itself onto the
                // backdrop through `track`, or it samples the old spot.
                Binding {
                    target: loader.item
                    property: "track"
                    when: !!loader.item
                    value: [menuLayer.panelRect.x, menuLayer.panelRect.y, menuLayer.panelWidth, menuLayer.panelHeight]
                }
            }
        }
    }

    // --- Menus -------------------------------------------------------------------

    Component {
        id: networkMenu
        NetworkMenu {
            chrome: false
            backdrop: menuBackdrop
            onPasswordRequested: network => {
                Menus.close();
                Dialogs.askWifiPassword(network);
            }
        }
    }

    Component {
        id: bluetoothMenu
        BluetoothMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: batteryMenu
        BatteryMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: systemMenu
        SystemMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: notificationCenter
        NotificationCenter { backdrop: menuBackdrop }
    }

    Component {
        id: controlCenterMenu
        ControlCenter { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: soundMenu
        SoundMenu { chrome: false; backdrop: menuBackdrop }
    }
}
