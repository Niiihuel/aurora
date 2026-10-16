import QtQuick
import "../../core"
import ".."

/**
 * A menu slider (volume, brightness). The accent fill follows `value` (0–1);
 * dragging or clicking anywhere on the row emits `moved(v)` and the owner
 * applies it, so the slider always shows the real level.
 *
 * Its thumb is Apple's liquid glass knob: a solid white capsule at rest that,
 * while dragged, lifts into a clear lens over a hidden copy of the track, so
 * the fill and track show magnified through it.
 */
Item {
    id: root

    property real value: 0
    property Item backdrop: null
    signal moved(real v)

    width: parent ? parent.width : 0
    height: 32

    readonly property real inset: Tokens.menu.itemInset
    readonly property real span: width - 2 * inset - knob.width
    readonly property real knobX: inset + Math.max(0, Math.min(1, value)) * span

    // The track as the lifted knob should see it: hidden from the scene and
    // lensed by the knob only. Same geometry as the visible track.
    Item {
        id: trackCopy
        anchors.fill: parent
        Rectangle {
            x: root.inset; width: root.width - 2 * root.inset
            height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)
            Rectangle {
                width: root.knobX - root.inset + knob.width / 2
                height: parent.height; radius: parent.radius
                color: Tokens.accent
            }
        }
    }

    Rectangle {
        x: root.inset; width: root.width - 2 * root.inset
        height: 6; radius: 3
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)
        Rectangle {
            width: root.knobX - root.inset + knob.width / 2
            height: parent.height; radius: parent.radius
            color: Tokens.accent
        }
    }

    Glass {
        id: knob
        x: root.knobX
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 16
        radius: height / 2
        backdrop: root.backdrop
        refracts: trackCopy
        hideRefracted: true
        material: Tokens.glass.sliderKnob
        liftedMaterial: Tokens.glass.lens
        held: drag.pressed
        pressScale: 1.4
        shadow: false
        track: [x, root.value]
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        preventStealing: true
        function apply(mx) {
            root.moved(Math.max(0, Math.min(1, (mx - root.inset - knob.width / 2) / Math.max(1, root.span))));
        }
        onPressed: mouse => apply(mouse.x)
        onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
    }
}
