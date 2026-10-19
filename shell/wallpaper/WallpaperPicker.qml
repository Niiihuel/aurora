import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
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
 * The lens behaves like the segmented control's knob: it lifts a little and
 * magnifies more while the row glides under it, and lands on Motion.land (a
 * squash and a rebound) as the choice settles. Applying grows the new
 * wallpaper out of the chosen thumbnail as a circle (Wallpaper.apply), like
 * a drop spreading, and the lens answers with the same press and landing.
 * The picker stays open so you can keep trying.
 *
 * ←/→ or the wheel move, Return or a click on the chosen one applies, a click
 * on a neighbour moves to it, Esc or a click outside closes.
 *
 * The last tile is +: it opens the system's file dialog (pictures, several
 * at once, from Downloads) with the picker stepped aside; what you choose is
 * copied into ~/wallpapers, and the picker comes back on the first of them
 * and applies it. Cancelling comes back on the +.
 */
PanelWindow {
    id: root

    property bool shown: false
    property int selected: 0
    /** The chosen picture's path, so a rescan that reorders the list keeps it. */
    property string chosen: ""
    readonly property var files: Wallpaper.files
    /** The pictures, then the + tile (""). */
    readonly property var tiles: files.concat([""])
    readonly property int addIndex: files.length
    /** A picture just added: applied as soon as it's listed. */
    property string pendingApply: ""

    onSelectedChanged: chosen = files[selected] || ""
    // The rescan on open can land after it (a new download shifts the list):
    // stay on the same picture, or on the + tile.
    onFilesChanged: {
        const i = files.indexOf(chosen);
        selected = !chosen.length ? addIndex : Math.max(0, i >= 0 ? i : Math.min(selected, addIndex));
        slide.snap(selected);
        if (i >= 0 && pendingApply === chosen) {
            pendingApply = "";
            Qt.callLater(apply);
        }
    }

    function toggle() {
        if (shown) {
            shown = false;
            return;
        }
        Wallpaper.rescan();
        const current = Wallpaper.pathFor(screen.name);
        selected = Math.max(0, files.indexOf(current));
        chosen = files[selected] || "";
        slide.snap(selected);
        shown = true;
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function move(step) {
        selected = Math.max(0, Math.min(addIndex, selected + step));
    }

    function apply() {
        if (selected === addIndex) {
            add();
            return;
        }
        const path = files[selected];
        if (!path)
            return;
        // Where the chosen thumbnail sits on the screen: the new wallpaper grows from there.
        const centre = lens.mapToItem(null, lens.width / 2, lens.height / 2);
        Wallpaper.apply(path, centre.x / root.width, centre.y / root.height);
        lens.bumping = true;
        bump.restart();
    }

    /** The + tile: the picker steps aside for the file dialog (it holds the keyboard). */
    function add() {
        shown = false;
        chooser.running = true;
    }
    Process {
        id: chooser
        command: ["kdialog", "--title", I18n.tr("wallpaper.addTitle"), "--multiple", "--separate-output",
            "--getopenfilename", Quickshell.env("HOME") + "/Downloads", "image/jpeg image/png image/webp"]
        stdout: StdioCollector {
            id: chooserOut
        }
        onExited: code => {
            const paths = code === 0 ? chooserOut.text.split("\n").filter(p => p.length) : [];
            if (paths.length) {
                const first = Wallpaper.dir + "/" + paths[0].slice(paths[0].lastIndexOf("/") + 1);
                root.chosen = first;
                root.pendingApply = first;
                Wallpaper.add(paths);
                // Already there by that name: nothing new gets listed, so go to it now.
                const i = root.files.indexOf(first);
                if (i >= 0) {
                    root.pendingApply = "";
                    root.selected = i;
                    slide.snap(i);
                    Qt.callLater(root.apply);
                }
            }
            root.shown = true;
            Qt.callLater(() => keys.forceActiveFocus());
        }
    }

    GlobalShortcut { appid: "aurora"; name: "wallpaperPicker"; description: "Choose a wallpaper"; onPressed: root.toggle() }
    GlobalShortcut { appid: "aurora"; name: "wallpaperNext"; description: "Next wallpaper, at random"; onPressed: Wallpaper.next() }

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
    /** The row is still more than half a step from the choice: the lens stays lifted. */
    readonly property bool moving: Math.abs(slide.to - slide.value) > 0.45

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

        // Clicks on the panel itself don't close it; the wheel moves one
        // picture per notch (a touchpad sends many small steps).
        MouseArea {
            id: wheelArea
            anchors.fill: parent
            property real wheel: 0
            onWheel: event => {
                wheelArea.wheel += event.angleDelta.y || event.angleDelta.x;
                if (Math.abs(wheelArea.wheel) < 120)
                    return;
                root.move(wheelArea.wheel > 0 ? -1 : 1);
                wheelArea.wheel = 0;
            }
        }

        Glass {
            anchors.fill: parent
            backdrop: pickerBackdrop
            material: Tokens.glass.regular
            radius: 32
            track: [panel.scale]
        }

        // The lens around the chosen wallpaper (it answers an apply with a press).
        Glass {
            id: lens
            readonly property real pad: 8
            width: root.focusWidth + 2 * pad
            height: root.focusHeight + 2 * pad
            x: (panel.width - width) / 2
            y: 20 - pad
            backdrop: pickerBackdrop
            material: Tokens.glass.lens
            liftedMaterial: Object.assign({}, Tokens.glass.lens, { magnify: 1.18 })
            radius: 22
            shadow: false
            held: root.moving || bumping
            pressScale: 1.06
            releasePreset: Motion.land
            track: [panel.scale, scale]
            /** An apply presses the lens for a beat; it lands like after a move. */
            property bool bumping: false
            Timer {
                id: bump
                interval: 90
                onTriggered: lens.bumping = false
            }
        }

        Item {
            id: strip
            anchors.fill: parent
            clip: true

            Repeater {
                model: root.tiles
                delegate: Item {
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property bool adder: !modelData.length
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
                    scale: s * (index === root.selected ? lens.scale : 1)
                    opacity: Math.max(0, 1 - 0.28 * ad)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Tokens.toggleOff

                        Image {
                            id: picture
                            anchors.fill: parent
                            // Kept decoded while closed (a few MB): reopening shows them at once.
                            source: tile.ad < 5 && !tile.adder ? "file://" + tile.modelData : ""
                            sourceSize: Qt.size(root.focusWidth * 1.5, root.focusHeight * 1.5)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }
                        // Neighbours lose colour and light with distance.
                        MultiEffect {
                            visible: !tile.adder
                            anchors.fill: parent
                            source: picture
                            saturation: -0.75 * Math.min(1, tile.ad)
                            brightness: -0.25 * Math.min(1, tile.ad)
                        }
                        Icon {
                            visible: tile.adder
                            anchors.centerIn: parent
                            glyph: Glyphs.plus
                            size: 44
                            color: Tokens.secondaryLabel
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
                if (root.selected === root.addIndex)
                    return I18n.tr("wallpaper.add");
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
