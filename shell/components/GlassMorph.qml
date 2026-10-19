import QtQuick
import QtQuick.Effects
import "../core"

/**
 * aurora's menu motion, shared by everything that pops a panel of glass out
 * of something you clicked: the menu bar's menus, Control Center, the
 * Notification Center, Settings' pop-up buttons.
 *
 * Fitted frame by frame to Apple's Liquid Glass (WWDC25 "Meet Liquid Glass"):
 * the glass leaves `fromRect` as a small clear drop that lenses what's behind
 * it, swells round first and then into the panel's rounded rectangle at
 * `toRect` on a slightly bouncy spring, gains its veil as it forms, and the
 * content focuses in from a blur once the shape is more than half formed.
 * Closing goes the other way without bounce: the panel shrinks evenly into a
 * drop while its content blurs out, and the drop melts into `fromRect`.
 * Moving `toRect` while open (a menu switch, content that grows) reshapes the
 * same glass; `refocus()` makes new content focus in again.
 *
 * Put the panel's content inside: it's laid out at `toRect` and revealed by
 * the glass. A `bare` panel (Control Center's grid of modules) has no glass of
 * its own: this glass carries the pop and hands over to the content as it
 * focuses in. Timings live in Motion (menuDrop/menuOpen/menuPhases,
 * menuClose/menuMerge/menuCloseHold).
 */
Item {
    id: root

    property bool open: false
    /** Where the glass comes from and returns to, in this item's coordinates. */
    property rect fromRect: Qt.rect(0, 0, 0, 0)
    /** Where the panel sits once open. */
    property rect toRect: Qt.rect(0, 0, 0, 0)
    property real panelRadius: Tokens.radius.menu
    property Item backdrop: null
    /**
     * A panel over its own window's content (a pop-up button's menu) refracts
     * that content instead of the screen behind the window. Must not contain
     * this item.
     */
    property Item refracts: null
    property bool bare: false
    /**
     * A tooltip's pointer toward x (this item's coordinates; < 0 = none), on
     * the bottom edge (side +1) or the top (−1). `toRect` includes its length;
     * it grows in as the shape forms.
     */
    property real tailX: -1
    property int tailSide: 0
    readonly property real tailLength: 8
    readonly property real tailHalf: 8
    /** Extra geometry the glass depends on (whatever moves this item on screen). */
    property var track: []
    default property alias content: inner.data

    /** True from opening until the close has fully melted back. */
    property bool active: false
    readonly property bool settled: sx.settled && sy.settled && sw.settled && sh.settled
    /** 0 blurred out → 1 sharp: how far the content has focused in. */
    readonly property real reveal: Math.min(focusIn.value, focused)
    signal closed()

    function refocus() {
        focusIn.snap(0);
    }

    // --- Shape --------------------------------------------------------------------

    property bool dropping: false
    property bool merging: false
    readonly property var openPreset: dropping ? Motion.menuDrop : Motion.menuOpen
    readonly property var closePreset: merging ? Motion.menuMerge : Motion.menuClose

    SpringValue { id: sx; preset: root.open ? root.openPreset : root.closePreset; epsilon: 0.05 }
    SpringValue { id: sy; preset: root.open ? root.openPreset : root.closePreset; epsilon: 0.05 }
    SpringValue { id: sw; preset: root.open ? root.openPreset : root.closePreset; epsilon: 0.05 }
    SpringValue { id: sh; preset: root.open ? root.openPreset : root.closePreset; epsilon: 0.05 }

    /** Height of the panel last shown, to measure progress on the way back. */
    property real openHeight: 1
    /** 0 at `fromRect`, 1 at the full panel (overshoots a little). */
    readonly property real progress: Math.max(0, (sh.value - fromRect.height) / Math.max(1, openHeight - fromRect.height))

    /** The drop the panel leaves as: a circle at the source's centre, ~45% of the panel's shorter side. */
    readonly property rect dropRect: {
        const d = Math.max(28, Math.min(80, 0.45 * Math.min(toRect.width, toRect.height)));
        const cx = fromRect.x + fromRect.width / 2;
        return Qt.rect(cx - d / 2, fromRect.y - d * 0.25, d, d);
    }

    Timer {
        id: dropTimer
        interval: Motion.menuPhases.dropHold * 1000
        onTriggered: {
            root.dropping = false;
            root.aim(false);
        }
    }
    Timer {
        id: mergeTimer
        interval: Motion.menuCloseHold * 1000
        onTriggered: {
            root.merging = true;
            root.aim(false);
        }
    }

    function aim(fresh) {
        if (open) {
            merging = false;
            mergeTimer.stop();
        }
        if (fresh && open) {
            dropping = true;
            dropTimer.restart();
        }
        const to = !open ? (merging ? fromRect : dropRect) : dropping ? dropRect : toRect;
        if (open)
            openHeight = Math.max(1, toRect.height);
        if (fresh) {
            sx.snap(fromRect.x); sy.snap(fromRect.y); sw.snap(fromRect.width); sh.snap(fromRect.height);
        }
        sx.to = to.x; sy.to = to.y; sw.to = to.width; sh.to = to.height;
    }

    onOpenChanged: {
        if (open) {
            const fresh = !active;
            active = true;
            if (fresh) {
                clock = 0;
                popClock.restart();
            }
            // Let the content lay out before measuring where the glass goes.
            Qt.callLater(() => root.aim(fresh));
        } else {
            dropping = false;
            dropTimer.stop();
            merging = false;
            mergeTimer.restart();
            aim(false);
        }
    }
    onToRectChanged: if (open) aim(false)
    onSettledChanged: {
        if (settled && !open && merging && active) {
            active = false;
            closed();
        }
    }

    // --- Phases riding on the pop --------------------------------------------------

    SpringValue {
        id: carrier
        to: root.bare ? 0 : 1
        preset: Motion.smooth
    }
    SpringValue { id: focusIn; to: 1; preset: Motion.snappy }

    /** Seconds since the pop started; bloom, shape and focus follow it while opening. */
    property real clock: Motion.menuPhases.total
    NumberAnimation {
        id: popClock
        target: root
        property: "clock"
        from: 0
        to: Motion.menuPhases.total
        duration: Motion.menuPhases.total * 1000
    }

    function span(t, a, b) {
        return Math.max(0, Math.min(1, (t - a) / (b - a)));
    }
    readonly property var phase: Motion.menuPhases
    /** 0–1 faint bloom: up to its peak, then clearing. */
    readonly property real bloom: open
        ? (clock < phase.bloomPeak ? span(clock, 0, phase.bloomPeak) : 1 - span(clock, phase.bloomPeak, phase.bloomEnd))
        : Math.max(0, Math.min(1, 1 - progress))
    /** 0 = round drop, 1 = the panel's corners; closing loses them at once, like Apple's. */
    readonly property real shaped: open ? span(clock, phase.shapeStart, phase.shapeEnd) : span(progress, 0.8, 0.98)
    /** 0 = blurred out, 1 = sharp; closing blurs the content out early. */
    readonly property real focused: open ? span(clock, phase.focusStart, phase.focusEnd) : span(progress, 0.68, 0.98)

    // --- Scene ----------------------------------------------------------------------

    Glass {
        id: glass
        x: sx.value
        y: sy.value
        width: Math.max(1, sw.value)
        height: Math.max(1, sh.value)
        visible: root.active
        backdrop: root.backdrop
        refracts: root.refracts
        material: Tokens.glass.regular
        radius: {
            const drop = Math.min(width, height) / 2;
            return drop + (root.panelRadius - drop) * root.shaped;
        }
        bloom: root.bloom
        tail: root.tailX < 0 || !root.tailSide ? Qt.vector4d(0, 0, 0, 0)
            // Kept clear of the corners when the bubble is pushed against an edge.
            : Qt.vector4d(Math.max(root.panelRadius + root.tailHalf, Math.min(width - root.panelRadius - root.tailHalf, root.tailX - x)),
                root.tailHalf * root.shaped, root.tailLength * root.shaped, root.tailSide)
        // Closing keeps the veil: Apple's returning drop is the densest glass of the motion.
        presence: root.open ? 0.25 + 0.75 * root.shaped : 1
        opacity: (root.open ? 1 : root.span(root.progress, 0.0, 0.12)) * Math.max(1 - root.reveal, carrier.value)
        track: [sx.value, sy.value, sw.value, sh.value, root.track]
    }

    Item {
        id: clipper
        x: glass.x
        y: glass.y
        width: glass.width
        height: glass.height
        visible: root.active
        // The glass reveals the content while it morphs. At rest nothing clips:
        // a pressed module grows past the panel's edge (it lifts).
        clip: !(root.open && root.settled)

        // Clicks inside the panel stay inside.
        MouseArea { anchors.fill: parent }

        Item {
            id: placed
            x: root.toRect.x - clipper.x
            y: root.toRect.y - clipper.y
            width: root.toRect.width
            height: root.toRect.height
            opacity: root.reveal
            // Only while focusing in or out: at rest a layer is a frozen
            // snapshot and would stop the glass inside the content from living.
            layer.enabled: root.active && root.reveal < 0.999
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: 1 - root.reveal
            }

            Item {
                id: inner
                anchors.fill: parent
            }
        }
    }
}
