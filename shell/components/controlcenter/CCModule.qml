import QtQuick
import "../../core"
import ".."

/**
 * One Control Center module, after macOS Tahoe: a lighter platter of liquid
 * glass on the Control Center's panel. A 1×1 module is a circle, a 2×1 one a
 * capsule (`round`), larger ones rounded rectangles. Put its controls inside.
 * It pops in as the panel focuses (a small scale and fade on the snappy
 * spring, each row a beat after the one above).
 *
 * Pressing it (`pressed`, set by the module's own controls) grows it on the
 * press spring, like interactive glass. A module that is one action as a
 * whole sets `menuItem` so the keyboard reaches it like a menu row: ↑/↓ move,
 * Return calls `activated`; hover highlights it the same way.
 */
Item {
    id: root

    default property alias content: body.data
    property Item backdrop: null
    property bool round: false
    property bool menuItem: false
    property bool pressed: false
    property var material: Tokens.glass.module
    signal activated()

    readonly property real radius: round ? height / 2 : Tokens.controlCenter.radius
    readonly property Item panel: {
        for (let p = parent; p; p = p.parent)
            if (p.isMenuPanel)
                return p;
        return null;
    }
    readonly property bool highlighted: menuItem && !!panel && panel.highlighted === root

    function activate() {
        activated();
    }

    SpringValue {
        id: lift
        to: root.pressed && !Motion.reduced ? Motion.pressScale : 1
        preset: Motion.press
    }
    property bool shown: false
    SpringValue {
        id: appear
        to: root.shown ? 1 : 0
        preset: Motion.snappy
    }
    Timer {
        interval: Motion.menuPhases.focusStart * 1000 + 35 * Math.round(root.y / 75)
        running: true
        onTriggered: root.shown = true
    }
    scale: lift.value * (0.88 + 0.12 * appear.value)
    opacity: appear.value

    Glass {
        anchors.fill: parent
        backdrop: root.backdrop
        material: root.material
        radius: root.radius
        shadow: false
        held: root.pressed
        track: [root.x, root.y, lift.value, root.panel ? root.panel.track : null]
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.35)
        opacity: root.highlighted ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.hover } }
    }

    HoverHandler {
        enabled: root.menuItem
        onHoveredChanged: if (hovered && root.panel) root.panel.highlighted = root
    }

    Item {
        id: body
        anchors.fill: parent
    }
}
