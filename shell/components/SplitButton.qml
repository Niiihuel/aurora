import QtQuick
import "../core"

/**
 * macOS's split button: the main action on the left, a hairline, and a
 * chevron on the right that pops the other actions out as a menu of glass
 * (PopupMenu, with aurora's shared menu motion). `text` / `clicked` are the
 * main action; `menu` is the PopupMenu item list.
 */
Item {
    id: root

    property string text: ""
    property var menu: []
    property Item backdrop: null
    signal clicked()

    implicitWidth: label.implicitWidth + 2 * Tokens.space.l + 26
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
    }
    Rectangle {
        width: parent.width - 26
        height: parent.height
        radius: 7
        color: Tokens.toggleOff
        visible: main.pressed
    }

    Text {
        id: label
        x: Tokens.space.l
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
    }
    MouseArea {
        id: main
        width: parent.width - 26
        height: parent.height
        onClicked: root.clicked()
    }

    Rectangle {
        x: parent.width - 26
        y: 5
        width: 1
        height: parent.height - 10
        color: Tokens.separator
    }
    Icon {
        x: parent.width - 19
        anchors.verticalCenter: parent.verticalCenter
        glyph: Glyphs.chevron
        size: 10
        rotation: 90
        color: Tokens.secondaryLabel
    }
    MouseArea {
        x: parent.width - 26
        width: 26
        height: parent.height
        onClicked: popup.open ? popup.open = false : popup.show(root)
    }

    PopupMenu {
        id: popup
        items: root.menu
        backdrop: root.backdrop
    }
}
