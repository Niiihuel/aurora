import QtQuick
import "../core"

/**
 * A macOS text field: rounded box, placeholder in the tertiary label color,
 * and the accent focus ring while it has the keyboard. `secret` hides the
 * text with bullets. `accepted` fires on Return.
 */
Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool secret: false
    readonly property alias input: input
    signal accepted()

    implicitWidth: 240
    implicitHeight: 28

    function focusField() {
        input.forceActiveFocus();
    }

    // Focus ring, drawn outside the box like macOS.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 9
        color: "transparent"
        border.width: 3
        border.color: Qt.alpha(Tokens.accent, 0.5)
        opacity: input.activeFocus ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.hover } }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.9)
        border.width: 1
        border.color: Tokens.separator
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: Tokens.space.m
        visible: input.text.length === 0
        text: root.placeholder
        color: Tokens.tertiaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
    }

    TextInput {
        id: input
        anchors.verticalCenter: parent.verticalCenter
        x: Tokens.space.m
        width: parent.width - 2 * Tokens.space.m
        clip: true
        color: Tokens.label
        selectionColor: Qt.alpha(Tokens.accent, 0.4)
        selectedTextColor: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        onAccepted: root.accepted()
    }
}
