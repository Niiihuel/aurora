import QtQuick
import "../core"

/**
 * A menu of glass that pops out of a control inside an app window (a pop-up
 * button's choices, a split button's actions), with aurora's shared menu
 * motion (GlassMorph). It refracts the window's own content beneath it.
 *
 * `items`: [{ label, checked?, destructive?, enabled?, act }] — a check column
 * appears when any item can be checked. `show(control)` opens it under the
 * control (above it with `upward`, for controls near the bottom edge);
 * picking an item closes it and runs `act`; a click elsewhere or scrolling
 * closes it.
 */
Item {
    id: root

    property var items: []
    property Item backdrop: null
    property bool open: false
    property bool upward: false
    property rect from: Qt.rect(0, 0, 0, 0)
    property Item surface: null
    readonly property bool checks: items.some(i => i.checked !== undefined)

    anchors.fill: parent
    z: 1000
    visible: open || morph.active

    function show(control) {
        parent = control.Window.contentItem;
        const a = control.mapToItem(parent, 0, 0);
        from = Qt.rect(a.x, a.y, control.width, control.height);
        // Refract the window's own content (never this menu itself).
        surface = Array.from(parent.children).find(c => c !== root && c.visible) ?? null;
        open = true;
    }

    // A click elsewhere closes it, and so does scrolling (as on macOS: the
    // menu would otherwise float away from the control that opened it).
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
        fromRect: root.from
        toRect: {
            const w = Math.max(root.from.width, column.implicitWidth + 12, 180);
            const h = column.implicitHeight + 12;
            const x = Math.min(root.from.x + root.from.width - w, root.width - w - 8);
            return Qt.rect(Math.max(8, x), root.upward ? root.from.y - h - 4 : root.from.y + root.from.height + 4, w, h);
        }
        panelRadius: 10
        backdrop: root.backdrop
        refracts: root.surface

        Column {
            id: column
            x: 6
            y: 6
            width: parent.width - 12
            Repeater {
                model: root.items
                delegate: Item {
                    id: item
                    required property var modelData
                    readonly property bool enabled: modelData.enabled !== false
                    readonly property color ink: !enabled ? Tokens.tertiaryLabel
                        : hover.containsMouse ? "white"
                        : modelData.destructive ? Tokens.destructive : Tokens.label
                    width: column.width
                    implicitWidth: label.implicitWidth + (root.checks ? 30 : 16)
                    height: 26
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Tokens.accent
                        visible: hover.containsMouse && item.enabled
                    }
                    Icon {
                        visible: item.modelData.checked === true
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: Glyphs.checkmark
                        size: 12
                        stroke: 1.75
                        color: item.ink
                    }
                    Text {
                        id: label
                        x: root.checks ? 24 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 6
                        text: item.modelData.label
                        color: item.ink
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.body.size
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: item.enabled
                        onClicked: {
                            root.open = false;
                            item.modelData.act();
                        }
                    }
                }
            }
        }
    }
}
