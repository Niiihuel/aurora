import QtQuick
import "../../core"
import ".."

/**
 * macOS Tahoe's switch in aurora's liquid glass, matched frame by frame to
 * Apple's WWDC25 footage ("Meet Liquid Glass", the switch sequence; the
 * controls slide of "Build an AppKit app with the new design" for the
 * proportions): a 2.28:1 track, accent when on and a quiet fill when off,
 * and a capsule knob ~58% of the track's width, solid white at rest.
 *
 * Pressing lifts the knob into clear glass ~1.7x its size (about the
 * track's width), overflowing the track, lensing a hidden copy of it so the color shows magnified through.
 * It stays lifted for the whole travel, stretching a little with speed, and
 * settles back into the white knob as it arrives. The fill follows the
 * knob. Emits `toggled(on)`; the owner applies the change and feeds
 * `checked` back, so the switch always shows the real state.
 */
Item {
    id: root

    property bool checked: false
    property Item backdrop: null
    signal toggled(bool on)

    implicitWidth: 50
    implicitHeight: 22

    SpringValue {
        id: pos
        to: root.checked ? 1 : 0
        preset: Motion.snappy
    }

    readonly property real inset: 1.5
    readonly property real knobWidth: Math.round(width * 0.58)
    readonly property real knobX: inset + pos.value * (width - knobWidth - 2 * inset)
    /**
     * How "on" the track looks. It follows the knob on a curve: switching on,
     * the color arrives early; switching off, it lingers until the knob is
     * nearly home — as in Apple's footage.
     */
    readonly property real fill: Math.pow(Math.max(0, Math.min(1, pos.value)), 0.4)
    /** Travelling: lifted until it is nearly home (Apple drops it on arrival, not after). */
    readonly property bool moving: Math.abs(pos.to - pos.value) > 0.12
    /** The lifted knob stretches along its travel with speed. */
    readonly property real stretch: Math.min(0.12, Math.abs(pos.velocity) * 0.02)

    // The track as the lifted knob sees it: hidden from the scene, lensed
    // only. The clear margin is what the lens shows beyond the track's edges
    // (outside an item the capture repeats its border, so it would read as
    // track all the way out).
    Item {
        id: trackCopy
        anchors.fill: parent
        anchors.margins: -12
        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            radius: height / 2
            color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Tokens.accent
                opacity: root.fill
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Tokens.accent
            opacity: root.fill
        }
    }

    Glass {
        readonly property real extra: root.knobWidth * root.stretch
        x: root.knobX - extra / 2
        y: root.inset
        width: root.knobWidth + extra
        height: root.height - 2 * root.inset
        radius: height / 2
        backdrop: root.backdrop
        refracts: trackCopy
        hideRefracted: true
        material: Tokens.glass.switchKnob
        liftedMaterial: Tokens.glass.switchLens
        held: touch.pressed || root.moving
        pressScale: 1.7
        shadow: false
        liftShadow: false
        track: [x, width, root.fill]
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        anchors.margins: -4
        onClicked: root.toggled(!root.checked)
    }
}
