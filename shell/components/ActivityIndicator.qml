import QtQuick
import "../core"

/**
 * macOS's indeterminate progress indicator: twelve rounded spokes around a
 * centre, the lit one stepping clockwise and the rest fading behind it. Use it
 * wherever something is being looked for or connected (Searching for
 * networks…, Connecting…, checking for updates). It only animates while
 * visible.
 */
Item {
    id: root

    property real size: 14
    property color color: Tokens.secondaryLabel

    implicitWidth: size
    implicitHeight: size

    property int step: 0
    Timer {
        running: root.visible
        interval: 83
        repeat: true
        onTriggered: root.step = (root.step + 1) % 12
    }

    Repeater {
        model: 12
        delegate: Rectangle {
            required property int index
            readonly property int age: (root.step - index + 12) % 12
            x: (root.size - width) / 2
            y: 0
            width: Math.max(1.5, root.size * 0.12)
            height: root.size * 0.3
            radius: width / 2
            color: root.color
            opacity: Math.max(0.18, 1 - age / 9)
            transform: Rotation {
                origin.x: width / 2
                origin.y: root.size / 2
                angle: index * 30
            }
        }
    }
}
