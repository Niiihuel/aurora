import QtQuick
import "../core"

/**
 * A macOS push button: a capsule with its label. The default button (the one
 * Return triggers) is filled with the accent color and white text; others use
 * a quiet fill. Pressing dims it briefly, as macOS does. Disabled buttons
 * stay visible and dimmed.
 */
Item {
    id: root

    property string text: ""
    property bool isDefault: false
    signal clicked()

    implicitWidth: Math.max(88, label.implicitWidth + 2 * Tokens.space.xl)
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.isDefault ? Tokens.accent : (Tokens.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07))
        opacity: !root.enabled ? 0.45 : touch.pressed ? 0.75 : 1
        Behavior on opacity { NumberAnimation { duration: Motion.hover } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.isDefault ? "white" : Tokens.label
        opacity: root.enabled ? 1 : 0.5
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        font.weight: root.isDefault ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
