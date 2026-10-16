import QtQuick
import "../core"

/** A macOS checkbox: a small rounded box, accent-filled with a white check when on. */
Item {
    id: root

    property string text: ""
    property bool checked: false
    signal toggled(bool on)

    implicitWidth: box.width + Tokens.space.s + label.implicitWidth
    implicitHeight: 18

    Rectangle {
        id: box
        width: 14; height: 14
        anchors.verticalCenter: parent.verticalCenter
        radius: 4
        color: root.checked ? Tokens.accent : (Tokens.dark ? Qt.rgba(1, 1, 1, 0.10) : "white")
        border.width: root.checked ? 0 : 1
        border.color: Tokens.separator

        Icon {
            visible: root.checked
            anchors.centerIn: parent
            size: 11
            stroke: 2
            glyph: Glyphs.checkmark
            color: "white"
        }
    }

    Text {
        id: label
        anchors.left: box.right
        anchors.leftMargin: Tokens.space.s
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled(!root.checked)
    }
}
