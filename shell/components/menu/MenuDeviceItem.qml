import QtQuick
import "../../core"
import ".."

/**
 * A device or network row in a status menu, after macOS Tahoe's Wi-Fi and
 * Bluetooth menus: the glyph in a circle (accent-filled with a white glyph
 * when `active`, a quiet fill otherwise), the name, an optional status line
 * under it, and an optional trailing glyph (a lock for secured networks).
 *
 * It's a MenuItem underneath, so hover, keyboard, the selection flash and
 * `triggered` behave like every other row.
 */
MenuItem {
    id: root

    property var badge: []
    property bool active: false
    property string status: ""
    property var trailingGlyph: null

    height: status.length ? 40 : 32
    implicitWidth: 28 + Tokens.space.m + Math.max(title.implicitWidth, statusText.implicitWidth) + (trailingGlyph ? 24 : 0) + 2 * Tokens.menu.itemInset + Tokens.space.xl

    // The base row's own label stays empty; this layout replaces it.
    text: ""

    Rectangle {
        id: circle
        x: Tokens.menu.itemInset - 4
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26
        radius: 13
        color: root.active ? Tokens.accent
             : root.highlighted && !root.blink ? Qt.rgba(1, 1, 1, 0.22)
             : (Tokens.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))

        Icon {
            anchors.centerIn: parent
            size: 14
            glyph: root.badge
            color: root.active ? "white" : root.ink
            dimColor: root.active ? Qt.rgba(1, 1, 1, 0.4) : Qt.alpha(root.ink, 0.3)
        }
    }

    Column {
        anchors.left: circle.right
        anchors.leftMargin: Tokens.space.m
        anchors.right: lockIcon.visible ? lockIcon.left : parent.right
        anchors.rightMargin: Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            id: title
            width: parent.width
            text: root.name
            color: root.ink
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            elide: Text.ElideRight
        }
        Text {
            id: statusText
            visible: root.status.length > 0
            width: parent.width
            text: root.status
            color: root.highlighted && !root.blink ? Qt.rgba(1, 1, 1, 0.8) : Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
            elide: Text.ElideRight
        }
    }

    property string name: ""

    Icon {
        id: lockIcon
        visible: !!root.trailingGlyph
        anchors.right: parent.right
        anchors.rightMargin: Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        size: 12
        glyph: root.trailingGlyph ?? []
        color: root.highlighted && !root.blink ? "white" : Tokens.secondaryLabel
    }
}
