import QtQuick
import "../../core"

/**
 * A status menu's title row ("Sonido", "Wi-Fi"…) in bold, with an optional
 * switch on the trailing side for menus that turn their feature on and off.
 */
Item {
    id: root

    property alias title: label.text
    property bool hasSwitch: false
    property bool checked: false
    signal toggled(bool on)

    width: parent ? parent.width : 0
    height: 30

    Text {
        id: label
        x: Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        font.weight: Font.Bold
    }

    MenuSwitch {
        visible: root.hasSwitch
        anchors.right: parent.right
        anchors.rightMargin: Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: on => root.toggled(on)
    }
}
