pragma Singleton

import QtQuick
import Quickshell

/**
 * Which menu bar menu is open, shared by every screen's bar and menu layer.
 *
 * macOS behavior: a click on an extra opens its menu; while one is open,
 * moving the pointer onto another extra of the same bar switches to that
 * extra's menu at once (tracking); a click on the open extra, a click outside,
 * Esc or choosing an item closes it. `anchorX`/`anchorWidth` are the extra's
 * position on its screen, so the menu can align under it.
 */
Singleton {
    id: root

    property string active: ""
    property string screen: ""
    property real anchorX: 0
    property real anchorWidth: 0
    /** Bumps on every open/switch so panels can tell a switch from a reopen. */
    property int serial: 0

    readonly property bool isOpen: active.length > 0

    function open(id, screenName, x, w) {
        // `active` goes last: listeners react to it and read the rest.
        screen = screenName;
        anchorX = x;
        anchorWidth = w;
        serial++;
        tracked = false;
        active = id;
    }

    /**
     * True while the open menu got there by the pointer sliding onto its extra.
     * Clicking that extra then keeps it open (the click meant "this one"),
     * like a click on a closed extra; the next click closes it.
     */
    property bool tracked: false

    function toggle(id, screenName, x, w) {
        if (active === id && screen === screenName && !tracked)
            close();
        else if (active === id && screen === screenName)
            tracked = false;
        else
            open(id, screenName, x, w);
    }

    /** Pointer entered an extra: switch only if a menu is already open there. */
    function track(id, screenName, x, w) {
        if (isOpen && screen === screenName && active !== id) {
            open(id, screenName, x, w);
            tracked = true;
        }
    }

    function close() {
        active = "";
    }

    /**
     * Ask the focused screen's bar to open (or close) a menu by id, e.g. from
     * IPC or a keyboard shortcut. The bar knows where the extra sits.
     */
    /** ←/→ while a menu is open: move to the neighbouring menu of that bar. */
    signal stepRequested(int direction)
    function step(direction) {
        if (isOpen)
            stepRequested(direction);
    }

    /** A Control Center page to show when it opens (IPC, shortcuts); taken once. */
    property string page: ""

    property string requested: ""
    property int requestSerial: 0
    function request(id) {
        requested = id;
        requestSerial++;
    }

    // --- Tooltips ------------------------------------------------------------------

    /**
     * The hovered extra's tooltip (bar/TipLayer shows it): after a moment at
     * rest on an extra, or at once while one was just showing, so sliding
     * along the bar moves the bubble from extra to extra. A press or an open
     * menu puts it away. `tip` follows the extra live (a battery draining).
     */
    property Item tipOwner: null
    readonly property string tip: tipOwner ? tipOwner.tip : ""
    property bool tipShown: false
    property string tipScreen: ""
    property real tipX: 0
    property real tipWidth: 0

    function hoverTip(owner) {
        tipOwner = owner;
        if (tipShown || tipWarm.running)
            showTip();
        else
            tipDelay.restart();
    }
    function leaveTip(owner) {
        if (tipOwner !== owner)
            return;
        tipOwner = null;
        tipDelay.stop();
        if (tipShown) {
            tipShown = false;
            tipWarm.restart();
        }
    }
    function hideTip() {
        tipDelay.stop();
        tipWarm.stop();
        tipShown = false;
    }
    function showTip() {
        if (!tipOwner || !tip.length || isOpen)
            return;
        tipScreen = tipOwner.screenName;
        tipX = tipOwner.anchor();
        tipWidth = tipOwner.width;
        tipShown = true;
    }
    onActiveChanged: if (isOpen) hideTip()

    Timer {
        id: tipDelay
        interval: 600
        onTriggered: root.showTip()
    }
    Timer {
        id: tipWarm
        interval: 500
    }
}
