import QtQuick
import "../../core"

/**
 * A line of information in a menu (power source, time remaining…): secondary
 * text that isn't a command, so it never highlights and the keyboard skips it.
 */
Item {
    property alias text: label.text

    width: parent ? parent.width : 0
    implicitWidth: label.implicitWidth + 2 * Tokens.menu.itemInset
    height: 22

    Text {
        id: label
        x: Tokens.menu.itemInset
        width: parent.width - 2 * Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.secondaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        elide: Text.ElideRight
    }
}
