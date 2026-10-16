import QtQuick
import "../core"
import "../components"

/**
 * A pop-up button, after macOS: shows the current choice with a chevron;
 * clicking pops the list of choices out of it as a small menu of glass, with
 * the same motion as the menu bar's menus (GlassMorph), the current one
 * checked. `choices` is a list of { label, value };
 * picking emits `picked(value)` and the owner sets `value` from the real
 * state.
 */
Item {
    id: root

    property var choices: []
    property var value
    property Item backdrop: null
    signal picked(var value)

    readonly property string label: {
        const c = choices.find(c => c.value === value);
        return c ? c.label : "";
    }

    implicitWidth: Math.max(120, current.implicitWidth + 40)
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: touch.pressed ? Tokens.toggleOff : (Tokens.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
    }
    Text {
        id: current
        x: Tokens.space.m + 2
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 36
        text: root.label
        color: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        elide: Text.ElideRight
    }
    Icon {
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.m
        anchors.verticalCenter: parent.verticalCenter
        glyph: Glyphs.chevron
        size: 10
        rotation: 90
        color: Tokens.secondaryLabel
    }
    MouseArea {
        id: touch
        anchors.fill: parent
        onClicked: popup.open ? popup.open = false : popup.show()
    }

    // The choices: a menu of glass that pops out of the button with aurora's
    // shared menu motion (GlassMorph), over everything else in the window.
    Item {
        id: popup
        property bool open: false
        property rect from: Qt.rect(0, 0, 0, 0)
        property Item surface: null
        parent: root.Window.contentItem
        anchors.fill: parent
        z: 1000
        visible: open || morph.active

        function show() {
            const a = root.mapToItem(popup, 0, 0);
            from = Qt.rect(a.x, a.y, root.width, root.height);
            // Refract the window's own content (never this popup itself).
            surface = Array.from(parent.children).find(c => c !== popup && c.visible) ?? null;
            open = true;
        }

        // A click anywhere else closes it.
        MouseArea {
            anchors.fill: parent
            enabled: popup.open
            onPressed: popup.open = false
        }

        GlassMorph {
            id: morph
            anchors.fill: parent
            open: popup.open
            fromRect: popup.from
            toRect: {
                const w = Math.max(root.width, 180);
                const h = column.implicitHeight + 12;
                return Qt.rect(Math.min(popup.from.x, popup.width - w - 8), popup.from.y + popup.from.height + 4, w, h);
            }
            panelRadius: 10
            backdrop: root.backdrop
            refracts: popup.surface

            Column {
                id: column
                x: 6
                y: 6
                width: parent.width - 12
                Repeater {
                    model: root.choices
                    delegate: Item {
                        id: choice
                        required property var modelData
                        width: column.width
                        height: 26
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Tokens.accent
                            visible: hover.containsMouse
                        }
                        Icon {
                            visible: choice.modelData.value === root.value
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: Glyphs.checkmark
                            size: 12
                            stroke: 1.75
                            color: hover.containsMouse ? "white" : Tokens.label
                        }
                        Text {
                            x: 24
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 30
                            text: choice.modelData.label
                            color: hover.containsMouse ? "white" : Tokens.label
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.body.size
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                popup.open = false;
                                root.picked(choice.modelData.value);
                            }
                        }
                    }
                }
            }
        }
    }
}
