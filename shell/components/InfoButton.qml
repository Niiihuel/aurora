import QtQuick
import "../core"

/**
 * ⓘ: more about something, as macOS puts it next to a setting. A click pops
 * a tooltip of glass out of it with aurora's menu motion (GlassMorph),
 * centred on the button, above it or below when there's no room, its
 * pointer (part of the same glass) aimed at the button. Like
 * PopupMenu it refracts the window's own content. Esc, a click elsewhere or
 * scrolling closes it.
 */
Item {
    id: root

    property string text: ""
    property bool open: false

    implicitWidth: 16
    implicitHeight: 16

    Icon {
        anchors.centerIn: parent
        glyph: Glyphs.info
        size: 15
        color: touch.containsMouse || root.open ? Tokens.label : Tokens.secondaryLabel
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open ? root.open = false : pop.show()
    }

    // The bubble's size: the text on one line up to 300 pt, wrapped beyond.
    readonly property real pad: Tokens.space.l
    TextMetrics {
        id: metrics
        font.family: Tokens.family
        font.pixelSize: Tokens.type.subheadline.size
        text: root.text
    }
    Text {
        id: measure
        visible: false
        width: Math.min(300, Math.ceil(metrics.advanceWidth) + 1)
        text: root.text
        font: metrics.font
        wrapMode: Text.Wrap
    }

    // Over the whole window while shown.
    Item {
        id: pop
        property rect from: Qt.rect(0, 0, 0, 0)
        property Item surface: null
        readonly property real bubbleHeight: measure.implicitHeight + 2 * root.pad
        readonly property bool above: from.y - bubbleHeight - morph.tailLength - 4 >= 8
        // Below, the pointer's arrow covers the button's lower half: clear it.
        readonly property real below: 12

        anchors.fill: parent
        z: 1000
        visible: root.open || morph.active

        function show() {
            parent = root.Window.contentItem;
            const a = root.mapToItem(parent, 0, 0);
            from = Qt.rect(a.x, a.y, root.width, root.height);
            // Refract the window's own content (never this bubble itself).
            surface = Array.from(parent.children).find(c => c !== pop && c.visible) ?? null;
            root.open = true;
            keys.forceActiveFocus();
        }

        Item {
            id: keys
            Keys.onEscapePressed: root.open = false
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onPressed: root.open = false
            onWheel: wheel => {
                root.open = false;
                wheel.accepted = true;
            }
        }

        GlassMorph {
            id: morph
            anchors.fill: parent
            open: root.open
            fromRect: pop.from
            // The bubble and its pointer: the tip 4 pt off the button, more below it.
            toRect: {
                const w = measure.width + 2 * root.pad;
                const h = pop.bubbleHeight + tailLength;
                const x = Math.max(8, Math.min(pop.width - w - 8, pop.from.x + pop.from.width / 2 - w / 2));
                return Qt.rect(x, pop.above ? pop.from.y - h - 4 : pop.from.y + pop.from.height + pop.below, w, h);
            }
            tailX: pop.from.x + pop.from.width / 2
            tailSide: pop.above ? 1 : -1
            panelRadius: 10
            refracts: pop.surface

            Text {
                x: root.pad
                y: root.pad + (pop.above ? 0 : morph.tailLength)
                width: measure.width
                text: root.text
                color: Tokens.label
                font: metrics.font
                wrapMode: Text.Wrap
            }
        }
    }
}
