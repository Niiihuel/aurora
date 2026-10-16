import QtQuick
import Quickshell
import Quickshell.Wayland
import "core"
import "components"

/**
 * Foundations gallery: type scale, semantic colors, glass presets and the
 * motion springs on one overlay, for checking tokens with screenshots without
 * touching the running desktop. Run from the repo root:
 *
 *     quickshell -p shell/gallery.qml
 */
ShellRoot {
    PanelWindow {
        id: win

        screen: Quickshell.screens[0]
        readonly property point origin: Qt.point(40, 60)

        anchors { top: true; left: true }
        margins { top: origin.y; left: origin.x }
        implicitWidth: 1000
        implicitHeight: 760
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aurora-gallery"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        GlassBackdrop {
            id: sceneBackdrop
            screen: win.screen
            origin: win.origin
            region: Qt.rect(win.origin.x, win.origin.y, win.implicitWidth, win.implicitHeight)
        }

        component Caption: Text {
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.footnote.size
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
        }

        // --- Type scale on regular glass -------------------------------------
        Glass {
            id: typeCard
            x: 20; y: 20; width: 420; height: 560
            backdrop: sceneBackdrop
            material: Tokens.glass.regular
            radius: Tokens.radius.panel

            Column {
                anchors.fill: parent
                anchors.margins: Tokens.space.xxl
                spacing: Tokens.space.s

                Caption { text: "Type · Inter, macOS text styles" }

                Repeater {
                    model: ["largeTitle", "title1", "title2", "title3", "headline", "body", "callout", "subheadline", "footnote", "caption1", "caption2"]
                    delegate: Row {
                        required property string modelData
                        spacing: Tokens.space.l
                        Text {
                            width: 110
                            anchors.baseline: sample.baseline
                            text: modelData
                            color: Tokens.tertiaryLabel
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.footnote.size
                        }
                        Text {
                            id: sample
                            text: "Aurora " + Tokens.type[modelData].size + "/" + Tokens.type[modelData].line
                            color: Tokens.label
                            font.family: Tokens.type[modelData].size >= 20 ? Tokens.displayFamily : Tokens.family
                            font.pixelSize: Tokens.type[modelData].size
                            font.weight: Tokens.type[modelData].weight
                            lineHeight: Tokens.type[modelData].line
                            lineHeightMode: Text.FixedHeight
                        }
                    }
                }

                Item { width: 1; height: Tokens.space.l }
                Caption { text: "Labels" }
                Text { text: "Label — primary content"; color: Tokens.label; font.family: Tokens.family; font.pixelSize: Tokens.type.body.size }
                Text { text: "Secondary label"; color: Tokens.secondaryLabel; font.family: Tokens.family; font.pixelSize: Tokens.type.body.size }
                Text { text: "Tertiary label"; color: Tokens.tertiaryLabel; font.family: Tokens.family; font.pixelSize: Tokens.type.body.size }
            }
        }

        // --- Colors -------------------------------------------------------------
        Glass {
            x: 460; y: 20; width: 520; height: 96
            backdrop: sceneBackdrop
            material: Tokens.glass.regular
            radius: Tokens.radius.tile

            Caption { x: Tokens.space.xl; y: Tokens.space.l; text: "Semantic colors" }
            Row {
                x: Tokens.space.xl; y: 40
                spacing: Tokens.space.m
                Repeater {
                    model: [
                        { name: "accent", c: Tokens.accent }, { name: "destructive", c: Tokens.destructive },
                        { name: "success", c: Tokens.success }, { name: "warning", c: Tokens.warning },
                        { name: "label", c: Tokens.label }, { name: "secondary", c: Tokens.secondaryLabel },
                        { name: "separator", c: Tokens.separator }
                    ]
                    delegate: Column {
                        required property var modelData
                        spacing: 4
                        Rectangle { width: 56; height: 22; radius: 6; color: modelData.c; border.width: 1; border.color: Tokens.separator }
                        Text { text: modelData.name; color: Tokens.secondaryLabel; font.family: Tokens.family; font.pixelSize: Tokens.type.caption1.size }
                    }
                }
            }
        }

        // --- Glass presets ------------------------------------------------------
        Caption { x: 460; y: 132; text: "Glass · regular, clear, bar — press them" }
        Row {
            x: 460; y: 152
            spacing: 20
            Repeater {
                model: [
                    { name: "regular", m: Tokens.glass.regular, r: Tokens.radius.menu },
                    { name: "clear", m: Tokens.glass.clear, r: Tokens.radius.menu },
                    { name: "bar", m: Tokens.glass.bar, r: 8 }
                ]
                delegate: Glass {
                    required property var modelData
                    width: 160; height: 120
                    backdrop: sceneBackdrop
                    material: modelData.m
                    radius: modelData.r
                    interactive: true
                    // The first sample presses itself, so the response can be
                    // checked in screenshots without a pointer.
                    held: modelData.name === "regular" && win.autoPress
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name + (parent.pressed ? " · pressed" : "")
                        color: Tokens.label
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.headline.size
                        font.weight: Tokens.type.headline.weight
                    }
                }
            }
        }

        property bool autoPress: false
        Timer { interval: 1300; running: true; repeat: true; onTriggered: win.autoPress = !win.autoPress }

        // --- Segmented control: a lifted glass knob lensing its labels ----------
        Caption { x: 460; y: 600; text: "Lifted knob · refracts its own labels" }

        Item {
            id: seg
            x: 460; y: 624; width: 300; height: 44

            property int selected: 0
            Timer { interval: 1700; running: true; repeat: true; onTriggered: seg.selected = 1 - seg.selected }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Tokens.quaternaryLabel
            }

            Row {
                id: segLabels
                anchors.fill: parent
                Repeater {
                    model: ["For You", "Library"]
                    delegate: Item {
                        required property string modelData
                        width: seg.width / 2; height: seg.height
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Tokens.secondaryLabel
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.title3.size
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // The control as it looks *selected*: solid track and full-weight
            // labels. Hidden from the scene; it only shows through the lifted
            // knob, so the knob reads the way Apple's does while it slides.
            Item {
                id: segSelected
                anchors.fill: parent
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Tokens.solidFill
                }
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: ["For You", "Library"]
                        delegate: Item {
                            required property string modelData
                            width: seg.width / 2; height: seg.height
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: Tokens.label
                                font.family: Tokens.family
                                font.pixelSize: Tokens.type.title3.size
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }

            SpringValue {
                id: knobX
                to: seg.selected * seg.width / 2
                preset: Motion.snappy
                epsilon: 0.05
            }

            Glass {
                id: knob
                x: knobX.value + 3; y: 3
                width: seg.width / 2 - 6; height: seg.height - 6
                radius: height / 2
                backdrop: sceneBackdrop
                refracts: segSelected
                hideRefracted: true
                material: Tokens.glass.knob
                liftedMaterial: Tokens.glass.lens
                held: !knobX.settled
                pressScale: 1.22
                shadow: false
                track: [x]

            }
        }

        // --- Menu bar glyphs: every state ----------------------------------------
        Caption { x: 20; y: 684; text: "Glyphs · every state the menu bar can show" }
        Glass {
            x: 20; y: 704; width: 960; height: 40
            backdrop: sceneBackdrop
            material: Tokens.glass.bar
            radius: 10
            shadow: false
            Row {
                anchors.centerIn: parent
                spacing: 18
                Icon { glyph: Glyphs.aurora }
                Icon { glyph: Glyphs.ethernet }
                Icon { glyph: Glyphs.wifi(3) }
                Icon { glyph: Glyphs.wifi(2) }
                Icon { glyph: Glyphs.wifi(1) }
                Icon { glyph: Glyphs.wifi(0) }
                Icon { glyph: Glyphs.wifiOff }
                Icon { glyph: Glyphs.bluetooth("on") }
                Icon { glyph: Glyphs.bluetooth("off") }
                Icon { glyph: Glyphs.speaker(3) }
                Icon { glyph: Glyphs.speaker(2) }
                Icon { glyph: Glyphs.speaker(1) }
                Icon { glyph: Glyphs.speaker(0) }
                Icon { glyph: Glyphs.controlCenter }
                BatteryIcon { level: 1; anchors.verticalCenter: parent.verticalCenter }
                BatteryIcon { level: 0.55; charging: true; anchors.verticalCenter: parent.verticalCenter }
                BatteryIcon { level: 0.08; low: true; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // --- Springs ------------------------------------------------------------
        Caption { x: 460; y: 296; text: "Motion · smooth, snappy, bouncy, dismiss" }

        property bool flip: false
        Timer { interval: 1400; running: true; repeat: true; onTriggered: win.flip = !win.flip }

        Column {
            x: 460; y: 316
            spacing: 14
            Repeater {
                model: [
                    { name: "smooth", p: Motion.smooth }, { name: "snappy", p: Motion.snappy },
                    { name: "bouncy", p: Motion.bouncy }, { name: "dismiss", p: Motion.dismiss }
                ]
                delegate: Item {
                    id: lane
                    required property var modelData
                    width: 520; height: 52

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 1
                        color: Tokens.separator
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.name
                        color: Tokens.tertiaryLabel
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.footnote.size
                    }
                    SpringValue {
                        id: pos
                        to: win.flip ? 1 : 0
                        preset: lane.modelData.p
                    }
                    Glass {
                        x: 70 + pos.value * (lane.width - 70 - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96; height: 40
                        backdrop: sceneBackdrop
                        material: Tokens.glass.regularSmall
                        radius: 20
                        shadow: false
                        track: [x]
                    }
                }
            }
        }
    }
}
