import QtQuick
import "../../core"
import ".."

/**
 * A 1×1 Control Center control: a glass circle with a glyph. On, it turns
 * into a white disc with the glyph in the accent color, as in macOS Tahoe.
 * A click (or Return) emits `clicked`; the owner flips the real state and
 * feeds `on` back. A secondary click asks for its options (`opened`), like
 * Control-click in macOS.
 */
CCModule {
    id: root

    property var glyph: []
    property bool on: false
    signal clicked()
    signal opened()

    round: true
    menuItem: true
    pressed: touch.pressed
    onActivated: clicked()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "white"
        opacity: root.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.hover } }
    }

    Icon {
        anchors.centerIn: parent
        glyph: root.glyph
        size: Math.round(root.width * 0.34)
        color: root.on ? Tokens.accent : Tokens.label
        dimColor: root.on ? Qt.alpha(Tokens.accent, 0.4) : Tokens.tertiaryLabel
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.opened() : root.clicked()
    }
}
