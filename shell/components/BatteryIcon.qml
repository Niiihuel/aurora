import QtQuick
import "../core"

/**
 * The macOS battery glyph: a rounded body with a terminal nub, filled to
 * `level`. The fill turns red when `low`, and a bolt cut-out sits on top while
 * `charging`. Wider than the 16 pt grid, like the real one (25 × 12 pt).
 */
Item {
    id: root

    property real level: 1
    property bool charging: false
    property bool low: false
    property color color: Tokens.label

    implicitWidth: 25
    implicitHeight: 12

    Rectangle {
        id: body
        x: 0; y: 0
        width: 22; height: 12
        radius: 3.5
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(root.color, 0.45)

        Rectangle {
            x: 2; y: 2
            height: parent.height - 4
            width: Math.max(root.level > 0 ? 1.5 : 0, (parent.width - 4) * root.level)
            radius: 1.75
            color: root.low ? Tokens.destructive : root.color
        }
    }

    // Terminal nub.
    Rectangle {
        x: body.width + 1
        anchors.verticalCenter: body.verticalCenter
        width: 1.5; height: 4.5
        radius: 0.75
        color: Qt.alpha(root.color, 0.45)
    }

    Icon {
        visible: root.charging
        anchors.centerIn: body
        size: 11
        glyph: Glyphs.bolt
        // Drawn in the opposite ink so it reads on top of the fill.
        color: Tokens.solidFill
    }
}
