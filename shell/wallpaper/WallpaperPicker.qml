import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"

/**
 * The wallpaper picker (Super+C): a carousel on a panel of liquid glass at
 * the bottom of the focused screen. The chosen wallpaper is large, in a lens
 * of glass; its neighbours shrink, dim and lose colour with distance, so the
 * strip reads as depth, and the whole row glides on a spring as the choice
 * moves.
 *
 * Applying grows the new wallpaper out of the chosen thumbnail as a circle
 * (Wallpaper.apply), like a drop spreading, and the lens answers with a small
 * press. The picker stays open so you can keep trying.
 *
 * ←/→ or the wheel move, Return or a click on the chosen one applies, a click
 * on a neighbour moves to it, Esc or a click outside closes.
 */
PanelWindow {
    id: root

    property bool shown: false
    property int selected: 0
    readonly property var files: Wallpaper.files

    function toggle() {
        if (shown) {
            shown = false;
            return;
        }
        Wallpaper.rescan();
        const current = Wallpaper.pathFor(screen.name);
        selected = Math.max(0, files.indexOf(current));
        slide.snap(selected);
        shown = true;
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function move(step) {
        if (files.length)
            selected = Math.max(0, Math.min(files.length - 1, selected + step));
    }

    function apply() {
        const path = files[selected];
        if (!path)
            return;
        // Where the chosen thumbnail sits on the screen: the new wallpaper grows from there.
        const centre = lens.mapToItem(null, lens.width / 2, lens.height / 2);
        Wallpaper.apply(path, centre.x / root.width, centre.y / root.height);
        bump.restart();
    }

    GlobalShortcut { appid: "aurora"; name: "wallpaperPicker"; description: "Choose a wallpaper"; onPressed: root.toggle() }

    SpringValue {
        id: openness
        to: root.shown ? 1 : 0
        preset: root.shown ? Motion.smooth : Motion.dismiss
    }
    /** The carousel's position (fractional while gliding). */
    SpringValue {
        id: slide
        to: root.selected
        preset: Motion.snappy
        epsilon: 0.002
    }

    screen: {
        const focused = Hyprland.focusedMonitor;
        for (const s of Quickshell.screens)
            if (focused && s.name === focused.name)
                return s;
        return Quickshell.screens[0];
    }

    visible: shown || !openness.settled
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-wallpaper"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property real focusWidth: 340
    readonly property real focusHeight: Math.round(focusWidth / (root.width / Math.max(1, root.height)))

    MouseArea {
        anchors.fill: parent
        onPressed: root.shown = false
    }

    GlassBackdrop {
        id: pickerBackdrop
        screen: root.screen
        region: Qt.rect(panel.x, panel.y, panel.width, panel.height)
    }

    Item {
        id: keys
        focus: root.shown
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.shown = false;
            else if (event.key === Qt.Key_Left)
                root.move(-1);
            else if (event.key === Qt.Key_Right)
                root.move(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.apply();
            else
                return;
            event.accepted = true;
        }
    }

    Item {
        id: panel
        width: Math.min(root.width * 0.86, 1180)
        height: root.focusHeight + 92
        x: Math.round((root.width - width) / 2)
        y: root.height - height - Math.round(Math.max(40, root.height * 0.06))
        opacity: openness.value
        scale: 0.94 + 0.06 * openness.value
        transformOrigin: Item.Bottom

        // Clicks on the panel itself don't close it; the wheel moves.
        MouseArea {
            anchors.fill: parent
            onWheel: wheel => root.move(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
        }

        Glass {
            anchors.fill: parent
            backdrop: pickerBackdrop
            material: Tokens.glass.regular
            radius: 32
            track: [panel.scale]
        }

        Text {
            visible: !root.files.length
            anchors.centerIn: parent
            text: I18n.tr("wallpaper.empty")
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
        }

        // The lens around the chosen wallpaper (it answers an apply with a press).
        Glass {
            id: lens
            readonly property real pad: 8
            width: root.focusWidth + 2 * pad
            height: root.focusHeight + 2 * pad
            x: (panel.width - width) / 2
            y: 20 - pad
            visible: root.files.length > 0
            backdrop: pickerBackdrop
            material: Tokens.glass.lens
            radius: 22
            shadow: false
            scale: bumpScale
            property real bumpScale: 1
            track: [panel.scale, scale]
            SequentialAnimation {
                id: bump
                NumberAnimation { target: lens; property: "bumpScale"; to: 0.94; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: lens; property: "bumpScale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
        }

        Item {
            id: strip
            anchors.fill: parent
            clip: true

            Repeater {
                model: root.files
                delegate: Item {
                    id: tile
                    required property string modelData
                    required property int index
                    /** Distance from the chosen one, fractional while gliding. */
                    readonly property real d: index - slide.value
                    readonly property real ad: Math.abs(d)
                    readonly property real s: Math.max(0.5, 1 - 0.24 * Math.min(ad, 2))
                    visible: ad < 5
                    width: root.focusWidth
                    height: root.focusHeight
                    x: (panel.width - width) / 2 + Math.sign(d) * (ad <= 1 ? ad * (root.focusWidth * 0.78) : root.focusWidth * 0.78 + (ad - 1) * root.focusWidth * 0.55)
                    y: 20
                    z: -ad
                    scale: s * (index === root.selected ? lens.bumpScale : 1)
                    opacity: Math.max(0, 1 - 0.28 * ad)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Tokens.toggleOff

                        Image {
                            id: picture
                            anchors.fill: parent
                            source: root.visible && tile.visible ? "file://" + tile.modelData : ""
                            sourceSize: Qt.size(root.focusWidth * 1.5, root.focusHeight * 1.5)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }
                        // Neighbours lose colour and light with distance.
                        MultiEffect {
                            anchors.fill: parent
                            source: picture
                            saturation: -0.75 * Math.min(1, tile.ad)
                            brightness: -0.25 * Math.min(1, tile.ad)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (tile.index === root.selected)
                                root.apply();
                            else
                                root.selected = tile.index;
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: root.focusWidth
            horizontalAlignment: Text.AlignHCenter
            text: {
                const path = root.files[root.selected] || "";
                return path.slice(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
            }
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.callout.size
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
        }
    }
}
