import QtQuick
import QtQuick.Effects
import "../../core"
import ".."

/**
 * macOS switch: accent track when on, quiet fill when off, a white knob that
 * slides on the snappy spring. While pressed the knob grows a little, the
 * same response as interactive glass. Emits `toggled(on)`; the owner applies
 * the change and feeds `checked` back, so the switch always shows real state.
 */
Item {
    id: root

    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 32
    implicitHeight: 19

    SpringValue {
        id: pos
        to: root.checked ? 1 : 0
        preset: Motion.snappy
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Tokens.accent
            opacity: pos.value
        }
    }

    RectangularShadow {
        anchors.fill: knob
        radius: knob.radius
        offset: Qt.vector2d(0, 0.5)
        blur: 2
        color: Qt.rgba(0, 0, 0, 0.3)
        scale: knob.scale
    }

    Rectangle {
        id: knob
        width: root.height - 4
        height: width
        radius: width / 2
        y: 2
        x: 2 + pos.value * (root.width - width - 4)
        color: "white"
        scale: touch.pressed && !Motion.reduced ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: Motion.hover; easing.type: Motion.easeOut } }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        anchors.margins: -4
        onClicked: root.toggled(!root.checked)
    }
}
