import QtQuick
import "../core"
import "../components"

/**
 * A pop-up button, after macOS: shows the current choice with a chevron;
 * clicking pops the list of choices out of it as a menu of glass
 * (components/PopupMenu, the shared menu motion), the current one checked. `choices` is a list of { label, value };
 * picking emits `picked(value)` and the owner sets `value` from the real
 * state.
 */
Item {
    id: root

    property var choices: []
    property var value
    property Item backdrop: null
    signal picked(var value)

    readonly property string label: {
        const c = choices.find(c => c.value === value);
        return c ? c.label : "";
    }

    implicitWidth: Math.max(120, current.implicitWidth + 40)
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: touch.pressed ? Tokens.toggleOff : (Tokens.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
    }
    Text {
        id: current
        x: Tokens.space.m + 2
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 36
        text: root.label
        color: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        elide: Text.ElideRight
    }
    Icon {
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.m
        anchors.verticalCenter: parent.verticalCenter
        glyph: Glyphs.chevron
        size: 10
        rotation: 90
        color: Tokens.secondaryLabel
    }
    MouseArea {
        id: touch
        anchors.fill: parent
        onClicked: popup.open ? popup.open = false : popup.show(root)
    }

    PopupMenu {
        id: popup
        backdrop: root.backdrop
        items: root.choices.map(c => ({ label: c.label, checked: c.value === root.value, act: () => root.picked(c.value) }))
    }
}
