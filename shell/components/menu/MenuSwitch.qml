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
 * Pressing lifts the knob into clear glass ~1.45x the track's height but
 * only ~0.72 of its width (Apple's lens is narrower than tall-scaled, its
 * corners a little flatter than a capsule's), overflowing the track and
 * lensing a hidden copy of it so the color shows magnified through. The
 * knob moves like a drop being pulled: its two edges ride different
 * springs, the one facing the travel first and the other behind, so it
 * stretches ~14% along its way and gathers itself back as it lands, while
 * the lift relaxes on Motion.land (a squash and a rebound). The fill
 * follows the knob. Emits `toggled(on)`; the owner applies the change and
 * feeds `checked` back, so the switch always shows the real state.
 */
Item {
    id: root

    property bool checked: false
    property Item backdrop: null
    signal toggled(bool on)

    implicitWidth: 50
    implicitHeight: 22

    readonly property real inset: 1.5
    readonly property real knobWidth: Math.round(width * 0.58)
    readonly property real travel: width - knobWidth - 2 * inset
    readonly property real restX: inset + (checked ? travel : 0)
    // The edge facing the travel sets off on the snappy spring, the other
    // follows on the smooth one: the knob stretches as it's pulled and
    // gathers back as it arrives (simulated: +14% at ~110 ms, rest by ~450 ms).
    SpringValue {
        id: leftEdge
        to: root.restX
        preset: root.checked ? Motion.smooth : Motion.snappy
    }
    SpringValue {
        id: rightEdge
        to: root.restX + root.knobWidth
        preset: root.checked ? Motion.snappy : Motion.smooth
    }
    readonly property real knobX: leftEdge.value
    readonly property real knobSpan: rightEdge.value - leftEdge.value
    /** 0 off → 1 on, from the knob's centre. */
    readonly property real pos: ((leftEdge.value + rightEdge.value - knobWidth) / 2 - inset) / Math.max(1, travel)
    /**
     * How "on" the track looks. It follows the knob on a curve: switching on,
     * the color arrives early; switching off, it lingers until the knob is
     * nearly home — as in Apple's footage.
     */
    readonly property real fill: Math.pow(Math.max(0, Math.min(1, pos)), 0.4)
    /** Travelling: lifted for the first half of the way; the land spring is still relaxing when it arrives. */
    readonly property bool moving: Math.abs((checked ? 1 : 0) - pos) > 0.5

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
        /** 0 at rest, 1 fully lifted (the glass scales itself on its lift spring). */
        readonly property real lifted: (scale - 1) / (pressScale - 1)
        x: root.knobX + (root.knobSpan - width) / 2
        y: root.inset
        width: root.knobSpan * (1 - 0.27 * lifted)
        height: root.height - 2 * root.inset
        radius: height / 2 * (1 - 0.10 * lifted)
        backdrop: root.backdrop
        refracts: trackCopy
        hideRefracted: true
        material: Tokens.glass.switchKnob
        liftedMaterial: Tokens.glass.switchLens
        held: touch.pressed || root.moving
        pressScale: 1.7
        releasePreset: Motion.land
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
