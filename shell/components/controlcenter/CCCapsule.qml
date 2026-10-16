import QtQuick
import "../../core"
import ".."

/**
 * A 2×1 Control Center control (Wi-Fi, Focus): a glass capsule with a round
 * button and the control's name and status. The button flips it
 * (`toggled`); the name opens its options (`opened`) when it has any, like
 * macOS ("click an icon to turn it on or off; click the item to show more").
 * On, the button is a white disc with the glyph in the accent color.
 */
CCModule {
    id: root

    property var glyph: []
    property bool on: false
    property string title: ""
    property string status: ""
    property bool hasDetail: true
    signal toggled()
    signal opened()

    round: true
    menuItem: true
    pressed: button.pressed || label.pressed
    onActivated: hasDetail ? opened() : toggled()

    Rectangle {
        id: disc
        x: (root.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.controlCenter.toggle
        height: width
        radius: width / 2
        color: root.on ? "white" : Tokens.toggleOff
        Behavior on color { ColorAnimation { duration: Motion.hover } }

        Icon {
            anchors.centerIn: parent
            glyph: root.glyph
            size: 17
            color: root.on ? Tokens.accent : Tokens.label
            dimColor: root.on ? Qt.alpha(Tokens.accent, 0.4) : Tokens.tertiaryLabel
        }

        MouseArea {
            id: button
            anchors.fill: parent
            onClicked: root.toggled()
        }
    }

    Column {
        anchors.left: disc.right
        anchors.leftMargin: Tokens.space.s
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.m
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: parent.width
            text: root.title
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.callout.size
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: root.status
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: label
        anchors.fill: parent
        anchors.leftMargin: disc.x + disc.width
        onClicked: root.hasDetail ? root.opened() : root.toggled()
    }
}
