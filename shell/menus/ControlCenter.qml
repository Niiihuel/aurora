import QtQuick
import Quickshell
import Quickshell.Widgets
import "../core"
import "../components"
import "../components/controlcenter"
import "../services"

/**
 * Control Center, after macOS Tahoe: a panel of glass holding a 4-column
 * grid where every module is its own lighter platter of liquid glass.
 *
 *   ( Wi-Fi        )  ┌ Now Playing ┐
 *    (BT)  (Airpl.)   └─────────────┘
 *   ( Do Not Dist. )  (Night) (Energy)
 *   ┌ Display ── ☼ ════════════ ☀ ┐
 *   ┌ Sound ──── ◁ ════════════ ◀) (⇵) ┐
 *    (Dark) (Shot) (Picker) (Keys)
 *
 * Clicking a glyph flips that feature; clicking a module's name (Wi-Fi), Now
 * Playing, Energy, Sound's output button or secondary-clicking Bluetooth
 * shows its options as a page: the page is
 * that extra's own menu on a panel of glass that the menu layer reshapes to,
 * and it fades in. Esc or the back row steps back; Esc on the grid closes.
 *
 * The menu layer's glass is the panel (`bare` stays false). It answers the
 * layer like a MenuPanel (`move`, `activate`, `highlighted`), forwarding to
 * the page while one is shown.
 */
Item {
    id: root

    property Item backdrop: null
    property bool chrome: true
    readonly property bool isMenuPanel: true
    readonly property bool bare: false
    readonly property real panelRadius: page.length ? Tokens.radius.menu : cc.radius + cc.padding
    property Item highlighted: null
    /** Window-space geometry the modules' glass depends on (set by the menu layer). */
    property var track: []

    /** "" for the grid, else "network", "bluetooth", "sound", "energy" or "media". */
    property string page: ""
    readonly property Item pageItem: page.length ? pageLoader.item : null

    readonly property var cc: Tokens.controlCenter
    readonly property real unit: (cc.width - 3 * cc.gap) / 4

    implicitWidth: pageItem ? pageItem.implicitWidth : cc.width + 2 * cc.padding
    implicitHeight: pageItem ? back.height + pageItem.implicitHeight : 6 * unit + 5 * cc.gap + 2 * cc.padding

    Component.onCompleted: {
        DisplayStatus.refresh();
        if (Menus.page.length) {
            open(Menus.page);
            Menus.page = "";
        }
    }

    /** Grid geometry: where column/row `i` starts, and how long `n` units are. */
    function at(i) {
        return i * (unit + cc.gap);
    }
    function span(n) {
        return n * unit + (n - 1) * cc.gap;
    }

    function open(name) {
        highlighted = null;
        page = name;
        reveal.restart();
    }

    /** Esc: step back (page's own level first). False on the grid. */
    function back() {
        if (pageItem && pageItem.back && pageItem.back())
            return true;
        if (!page.length)
            return false;
        open("");
        return true;
    }

    /** Run a tool once Control Center is out of the way (a screenshot shouldn't catch it). */
    function launch(command) {
        Menus.close();
        Quickshell.execDetached(["sh", "-c", "sleep 0.45; exec \"$@\"", "_"].concat(command));
    }

    function rows() {
        const found = [];
        const walk = item => {
            for (const child of item.children) {
                if (!child.visible)
                    continue;
                if (child.menuItem === true)
                    found.push(child);
                else
                    walk(child);
            }
        };
        walk(grid);
        found.sort((a, b) => (a.y - b.y) || (a.x - b.x));
        return found;
    }

    function move(step) {
        if (pageItem)
            return pageItem.move(step);
        const list = rows();
        if (!list.length)
            return;
        const i = list.indexOf(highlighted);
        highlighted = i < 0 ? list[step > 0 ? 0 : list.length - 1] : list[(i + step + list.length) % list.length];
    }

    function activate() {
        if (pageItem)
            pageItem.activate();
        else if (highlighted)
            highlighted.activate();
    }

    // Standalone (gallery): the panel of glass.
    Glass {
        visible: root.chrome
        anchors.fill: parent
        backdrop: root.backdrop
        material: Tokens.glass.regular
        radius: root.panelRadius
    }

    // The content that just changed fades in while the glass reshapes.
    NumberAnimation {
        id: reveal
        target: content
        property: "opacity"
        from: Motion.reduced ? 1 : 0
        to: 1
        duration: Motion.quick
        easing.type: Motion.easeOut
    }

    HoverHandler {
        onHoveredChanged: if (!hovered) root.highlighted = null
    }

    Item {
        id: content
        anchors.fill: parent

        // --- The grid ----------------------------------------------------------

        Item {
            id: grid
            anchors.fill: parent
            anchors.margins: root.cc.padding
            visible: !root.page.length

            CCCapsule {
                x: root.at(0); y: root.at(0); width: root.span(2); height: root.unit
                backdrop: root.backdrop
                glyph: NetworkStatus.wifiEnabled ? Glyphs.wifi(3) : Glyphs.wifiOff
                on: NetworkStatus.wifiEnabled
                title: I18n.tr("network.wifi")
                status: !NetworkStatus.wifiEnabled ? I18n.tr("controlCenter.off")
                      : NetworkStatus.wifiNetwork ? NetworkStatus.wifiNetwork.name
                      : I18n.tr("controlCenter.notConnected")
                onToggled: NetworkStatus.setWifiEnabled(!NetworkStatus.wifiEnabled)
                onOpened: root.open("network")
            }

            CCButton {
                x: root.at(0); y: root.at(1); width: root.unit; height: root.unit
                visible: BluetoothStatus.present
                backdrop: root.backdrop
                glyph: Glyphs.bluetooth(BluetoothStatus.enabled ? "on" : "off")
                on: BluetoothStatus.enabled
                onClicked: BluetoothStatus.setEnabled(!BluetoothStatus.enabled)
                onOpened: root.open("bluetooth")
            }

            CCButton {
                x: root.at(1); y: root.at(1); width: root.unit; height: root.unit
                backdrop: root.backdrop
                glyph: Glyphs.airplane
                on: NetworkStatus.airplane
                onClicked: NetworkStatus.setAirplane(!NetworkStatus.airplane)
            }

            // Now Playing: artwork, title, artist and the transport.
            CCModule {
                x: root.at(2); y: root.at(0); width: root.span(2); height: root.span(2)
                backdrop: root.backdrop
                menuItem: true
                pressed: openMedia.pressed
                onActivated: root.open("media")

                MouseArea {
                    id: openMedia
                    anchors.fill: parent
                    onClicked: root.open("media")
                }

                ClippingRectangle {
                    id: art
                    x: Tokens.space.l
                    y: Tokens.space.l
                    width: 40
                    height: 40
                    radius: 9
                    color: Tokens.toggleOff

                    Image {
                        anchors.fill: parent
                        source: MediaStatus.art
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Icon {
                        visible: !MediaStatus.art.length
                        anchors.centerIn: parent
                        glyph: Glyphs.play
                        size: 14
                        color: Tokens.secondaryLabel
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: art.bottom
                    anchors.leftMargin: Tokens.space.l
                    anchors.rightMargin: Tokens.space.l
                    anchors.topMargin: Tokens.space.s

                    Text {
                        width: parent.width
                        text: MediaStatus.present ? MediaStatus.title : I18n.tr("controlCenter.notPlaying")
                        color: MediaStatus.present ? Tokens.label : Tokens.secondaryLabel
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.callout.size
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: MediaStatus.artist
                        color: Tokens.secondaryLabel
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.subheadline.size
                        elide: Text.ElideRight
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.space.s
                    spacing: Tokens.space.l
                    opacity: MediaStatus.present ? 1 : 0.4

                    Repeater {
                        model: [
                            { glyph: Glyphs.backward, act: () => MediaStatus.previous() },
                            { glyph: MediaStatus.playing ? Glyphs.pause : Glyphs.play, act: () => MediaStatus.toggle() },
                            { glyph: Glyphs.forward, act: () => MediaStatus.next() }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: 28
                            height: 28
                            Icon {
                                anchors.centerIn: parent
                                glyph: modelData.glyph
                                size: 17
                                scale: press.pressed ? 0.88 : 1
                            }
                            MouseArea {
                                id: press
                                anchors.fill: parent
                                onClicked: modelData.act()
                            }
                        }
                    }
                }
            }

            CCCapsule {
                x: root.at(0); y: root.at(2); width: root.span(2); height: root.unit
                backdrop: root.backdrop
                glyph: Glyphs.moon
                on: Settings.doNotDisturb
                title: I18n.tr("controlCenter.focus")
                status: Settings.doNotDisturb ? I18n.tr("controlCenter.on") : ""
                hasDetail: false
                onToggled: Settings.doNotDisturb = !Settings.doNotDisturb
            }

            CCButton {
                x: root.at(2); y: root.at(2); width: root.unit; height: root.unit
                backdrop: root.backdrop
                glyph: Glyphs.nightLight
                on: DisplayStatus.nightLight
                onClicked: DisplayStatus.setNightLight(!DisplayStatus.nightLight)
            }

            CCButton {
                x: root.at(3); y: root.at(2); width: root.unit; height: root.unit
                visible: BatteryStatus.present
                backdrop: root.backdrop
                glyph: BatteryStatus.mode === "saver" ? Glyphs.leaf : BatteryStatus.mode === "performance" ? Glyphs.bolt : Glyphs.gauge
                on: BatteryStatus.mode !== "balanced"
                onClicked: root.open("energy")
            }

            CCModule {
                x: root.at(0); y: root.at(3); width: root.span(4); height: root.unit
                visible: DisplayStatus.hasBacklight
                backdrop: root.backdrop

                Text {
                    x: Tokens.space.l + 2
                    y: Tokens.space.m + 2
                    text: I18n.tr("controlCenter.display")
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                    font.weight: Font.DemiBold
                }
                CCSlider {
                    backdrop: root.backdrop
                    x: Tokens.space.l
                    width: parent.width - 2 * Tokens.space.l
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.space.m
                    lowGlyph: Glyphs.sun
                    highGlyph: Glyphs.sun
                    value: DisplayStatus.brightness
                    onMoved: v => DisplayStatus.setBrightness(v)
                }
            }

            CCModule {
                x: root.at(0); y: root.at(4); width: root.span(4); height: root.unit
                visible: AudioStatus.ready
                backdrop: root.backdrop

                Text {
                    x: Tokens.space.l + 2
                    y: Tokens.space.m + 2
                    text: I18n.tr("sound.title")
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                    font.weight: Font.DemiBold
                }
                CCSlider {
                    id: soundSlider
                    backdrop: root.backdrop
                    x: Tokens.space.l
                    width: parent.width - 2 * Tokens.space.l - outputs.width - Tokens.space.s
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.space.m
                    lowGlyph: Glyphs.speaker(1)
                    highGlyph: Glyphs.speaker(3)
                    value: AudioStatus.muted ? 0 : AudioStatus.volume
                    onMoved: v => AudioStatus.setVolume(v)
                }
                // Choose the output, like AirPlay's button in macOS's Sound module.
                Rectangle {
                    id: outputs
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.space.m
                    anchors.verticalCenter: soundSlider.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: Tokens.toggleOff
                    scale: outputsTouch.pressed ? 0.92 : 1
                    Icon {
                        anchors.centerIn: parent
                        glyph: Glyphs.output
                        size: 14
                    }
                    MouseArea {
                        id: outputsTouch
                        anchors.fill: parent
                        onClicked: root.open("sound")
                    }
                }
            }

            CCButton {
                x: root.at(0); y: root.at(5); width: root.unit; height: root.unit
                backdrop: root.backdrop
                glyph: Glyphs.darkMode
                on: Settings.dark
                onClicked: Settings.appearance = Settings.dark ? "light" : "dark"
            }

            CCButton {
                x: root.at(1); y: root.at(5); width: root.unit; height: root.unit
                backdrop: root.backdrop
                glyph: Glyphs.screenshot
                onClicked: {
                    Menus.close();
                    Capture.open();
                }
            }

            CCButton {
                x: root.at(2); y: root.at(5); width: root.unit; height: root.unit
                backdrop: root.backdrop
                glyph: Glyphs.eyedropper
                onClicked: root.launch(["hyprpicker", "-a"])
            }

            CCButton {
                x: root.at(3); y: root.at(5); width: root.unit; height: root.unit
                visible: DisplayStatus.hasKeyboardLight
                backdrop: root.backdrop
                glyph: Glyphs.keyboard
                on: DisplayStatus.keyboardLevel > 0
                onClicked: DisplayStatus.cycleKeyboard()
            }
        }

        // --- A page --------------------------------------------------------------

        Item {
            id: back
            visible: root.page.length > 0
            width: parent.width
            height: 30

            Row {
                x: Tokens.menu.padding + Tokens.menu.itemInset - 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space.xs
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Glyphs.chevronBack
                    size: 12
                    color: Tokens.secondaryLabel
                }
                Text {
                    text: I18n.tr("controlCenter.title")
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                    font.weight: Font.DemiBold
                }
            }
            TapHandler { onTapped: root.open("") }
        }

        Loader {
            id: pageLoader
            y: back.height
            active: root.page.length > 0
            sourceComponent: root.page === "network" ? networkPage
                : root.page === "bluetooth" ? bluetoothPage
                : root.page === "sound" ? soundPage
                : root.page === "energy" ? energyPage
                : root.page === "media" ? mediaPage : null
        }
    }

    Component {
        id: networkPage
        NetworkMenu {
            chrome: false
            backdrop: root.backdrop
            onPasswordRequested: network => {
                Menus.close();
                Dialogs.askWifiPassword(network);
            }
        }
    }
    Component {
        id: bluetoothPage
        BluetoothMenu { chrome: false; backdrop: root.backdrop }
    }
    Component {
        id: soundPage
        SoundMenu { chrome: false; backdrop: root.backdrop }
    }
    Component {
        id: energyPage
        BatteryMenu { chrome: false; backdrop: root.backdrop }
    }
    Component {
        id: mediaPage
        MediaPage { chrome: false; backdrop: root.backdrop }
    }
}
