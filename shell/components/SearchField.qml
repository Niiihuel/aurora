import QtQuick
import "../core"

/**
 * macOS Tahoe's search field: a capsule with the magnifier, the placeholder
 * in the tertiary label colour, and a clear button once there's text.
 * `text` is the query; Esc clears it.
 */
Item {
    id: root

    property alias text: input.text
    property string placeholder: I18n.tr("launcher.placeholder")

    implicitWidth: 220
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
        border.width: input.activeFocus ? 2 : 0
        border.color: Qt.alpha(Tokens.accent, 0.6)
    }

    Icon {
        id: lens
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        glyph: Glyphs.magnifier
        size: 13
        color: Tokens.secondaryLabel
    }

    TextInput {
        id: input
        anchors.left: lens.right
        anchors.leftMargin: Tokens.space.s
        anchors.right: clear.left
        anchors.rightMargin: Tokens.space.xs
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.label
        selectionColor: Tokens.accent
        selectedTextColor: "white"
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        clip: true
        Keys.onEscapePressed: text = ""

        Text {
            visible: !input.text.length
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Tokens.tertiaryLabel
            font: input.font
        }
    }

    Item {
        id: clear
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        width: input.text.length ? 16 : 0
        height: 16
        visible: input.text.length > 0
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Tokens.tertiaryLabel
        }
        Icon {
            anchors.centerIn: parent
            glyph: Glyphs.xmark
            size: 9
            stroke: 2
            color: Tokens.windowFill
        }
        MouseArea {
            anchors.fill: parent
            onClicked: input.text = ""
        }
    }
}
