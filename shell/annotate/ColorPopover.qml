import QtQuick
import "../core"
import "../components"
import "../services"
import "geometry.mjs" as G

/**
 * The editor's color picker (its glass is the toolbar's GlassMorph): a
 * saturation/brightness square, a hue strip, seven swatches and a hex field
 * (#rgb or #rrggbb; anything else goes back to the current color). Every
 * pick applies at once and it stays open; Esc or a click outside closes it.
 */
Item {
    id: root


    property real hue: 0
    property real sat: 1
    property real val: 1

    width: 220
    height: column.implicitHeight + 2 * Tokens.space.l

    function hexOf(c) {
        return "#" + [c.r, c.g, c.b].map(x => Math.round(x * 255).toString(16).padStart(2, "0")).join("");
    }
    function load() {
        const c = Qt.color(Annotate.style.color);
        hue = Math.max(0, c.hsvHue);
        sat = c.hsvSaturation;
        val = c.hsvValue;
        hex.text = Annotate.style.color;
    }
    function apply() {
        const c = hexOf(Qt.hsva(hue, sat, val, 1));
        hex.text = c;
        Annotate.setColor(c);
    }

    Connections {
        target: Annotate
        function onPopoverChanged() {
            if (Annotate.popover === "color")
                root.load();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Annotate.popover = "";
            event.accepted = true;
        }
    }


    Column {
        id: column
        x: Tokens.space.l
        y: Tokens.space.l
        width: root.width - 2 * Tokens.space.l
        spacing: Tokens.space.m

        // Saturation (→) and brightness (↓) for the hue.
        Rectangle {
            id: square
            width: parent.width
            height: 120
            radius: 8
            color: Qt.hsva(root.hue, 1, 1, 1)
            Rectangle {
                anchors.fill: parent
                radius: 8
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1; color: "black" }
                }
            }
            Rectangle {
                x: root.sat * square.width - 6
                y: (1 - root.val) * square.height - 6
                width: 12
                height: 12
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: "white"
            }
            MouseArea {
                anchors.fill: parent
                function pick(mouse) {
                    root.sat = G.clamp(mouse.x / width, 0, 1);
                    root.val = 1 - G.clamp(mouse.y / height, 0, 1);
                    root.apply();
                }
                onPressed: mouse => pick(mouse)
                onPositionChanged: mouse => pick(mouse)
            }
        }

        // Hue.
        Rectangle {
            id: hueStrip
            width: parent.width
            height: 14
            radius: 7
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.000; color: Qt.hsva(0.000, 1, 1, 1) }
                GradientStop { position: 0.167; color: Qt.hsva(0.167, 1, 1, 1) }
                GradientStop { position: 0.333; color: Qt.hsva(0.333, 1, 1, 1) }
                GradientStop { position: 0.500; color: Qt.hsva(0.500, 1, 1, 1) }
                GradientStop { position: 0.667; color: Qt.hsva(0.667, 1, 1, 1) }
                GradientStop { position: 0.833; color: Qt.hsva(0.833, 1, 1, 1) }
                GradientStop { position: 1.000; color: Qt.hsva(0.999, 1, 1, 1) }
            }
            Rectangle {
                x: root.hue * hueStrip.width - 3
                y: -2
                width: 6
                height: hueStrip.height + 4
                radius: 3
                color: "white"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                function pick(mouse) {
                    root.hue = G.clamp((mouse.x - 4) / hueStrip.width, 0, 0.999);
                    root.apply();
                }
                onPressed: mouse => pick(mouse)
                onPositionChanged: mouse => pick(mouse)
            }
        }

        // Swatches.
        Row {
            spacing: (parent.width - 7 * 22) / 6
            Repeater {
                model: Annotate.swatches
                delegate: Rectangle {
                    required property string modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: modelData
                    border.width: Annotate.style.color === modelData ? 2 : 1
                    border.color: Annotate.style.color === modelData ? "white" : Qt.rgba(1, 1, 1, 0.25)
                    scale: swatchHover.containsMouse ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    MouseArea {
                        id: swatchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Annotate.setColor(modelData);
                            root.load();
                        }
                    }
                }
            }
        }

        // The color and its hex.
        Row {
            spacing: Tokens.space.m
            Rectangle {
                width: 28
                height: 28
                radius: 7
                color: Annotate.style.color
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.3)
            }
            TextField {
                id: hex
                width: column.width - 28 - Tokens.space.m
                onAccepted: {
                    const c = G.parseHex(text);
                    if (c.length) {
                        Annotate.setColor(c);
                        root.load();
                    } else {
                        text = Annotate.style.color;
                    }
                }
            }
        }
    }
}
