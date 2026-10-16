import QtQuick
import "../../core"

/** A one-pixel group separator, inset from the menu's sides like macOS. */
Item {
    width: parent ? parent.width : 0
    height: 11

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Tokens.menu.separatorInset
        width: parent.width - 2 * Tokens.menu.separatorInset
        height: 1
        color: Tokens.separator
    }
}
