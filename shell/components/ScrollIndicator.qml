import QtQuick
import "../core"

/**
 * macOS's overlay scroll bar for a Flickable: a thin rounded thumb along the
 * trailing edge that appears while the content moves (or the pointer is on
 * it) and fades out a moment after. It widens under the pointer and can be
 * dragged. Place it next to the Flickable (same parent) and point
 * `flickable` at it.
 */
Item {
    id: root

    required property Flickable flickable
    /** Sit in the margin to the right of the content instead of over its edge. */
    property bool outside: true

    x: outside ? flickable.x + flickable.width + 6 : flickable.x + flickable.width - width - 2
    y: flickable.y + flickable.topMargin + 2
    width: 10
    height: flickable.height - flickable.topMargin - 4
    visible: flickable.visibleArea.heightRatio < 0.999
    z: 10

    property bool awake: false
    readonly property bool active: flickable.moving || hover.hovered || drag.pressed
    onActiveChanged: {
        if (active) {
            awake = true;
            sleep.stop();
        } else {
            sleep.restart();
        }
    }
    Timer {
        id: sleep
        interval: 900
        onTriggered: root.awake = false
    }

    HoverHandler { id: hover }

    Rectangle {
        readonly property real ratio: Math.max(0.08, root.flickable.visibleArea.heightRatio)
        anchors.right: parent.right
        width: hover.hovered || drag.pressed ? 8 : 5
        radius: width / 2
        height: Math.max(24, ratio * root.height)
        y: Math.max(0, Math.min(root.height - height, root.flickable.visibleArea.yPosition * root.height))
        color: Tokens.tertiaryLabel
        opacity: root.awake ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.quick } }
        Behavior on width { NumberAnimation { duration: Motion.hover } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        function scrollTo(y) {
            const f = root.flickable;
            const span = Math.max(1, f.contentHeight - f.height + f.topMargin);
            f.contentY = -f.topMargin + Math.max(0, Math.min(1, y / root.height)) * span;
        }
        onPressed: mouse => scrollTo(mouse.y)
        onPositionChanged: mouse => { if (pressed) scrollTo(mouse.y); }
    }
}
