import QtQuick
import "../../core"
import ".."

/**
 * macOS Tahoe's switch in aurora's liquid glass: the accent track when on, a
 * quiet one when off, and a capsule knob that is solid white at rest. While
 * pressed or sliding the knob lifts into a clear lens (like the slider's
 * thumb and the segmented control's knob) over a hidden copy of the track,
 * so the accent fill shows magnified through it, then settles back on the
 * snappy spring. Emits `toggled(on)`; the owner applies the change and feeds
 * `checked` back, so the switch always shows the real state.
 */
Item {
    id: root

    property bool checked: false
    property Item backdrop: null
    signal toggled(bool on)

    implicitWidth: 38
    implicitHeight: 22

    SpringValue {
        id: pos
        to: root.checked ? 1 : 0
        preset: Motion.snappy
    }

    readonly property real knobWidth: 24
    readonly property real knobX: 2 + pos.value * (width - knobWidth - 4)
    /** How "on" the track looks: follows the knob, so the fill grows with it. */
    readonly property real fill: Math.max(0, Math.min(1, pos.value))

    // The track as the lifted knob sees it: hidden from the scene, lensed only.
    Item {
        id: trackCopy
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
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
        x: root.knobX
        y: 3
        width: root.knobWidth
        height: root.height - 6
        radius: height / 2
        backdrop: root.backdrop
        refracts: trackCopy
        hideRefracted: true
        material: Tokens.glass.sliderKnob
        liftedMaterial: Tokens.glass.lens
        held: touch.pressed || !pos.settled
        pressScale: 1.3
        shadow: false
        track: [x, root.fill]
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        anchors.margins: -4
        onClicked: root.toggled(!root.checked)
    }
}
