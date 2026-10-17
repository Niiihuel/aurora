import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../components"
import "../menus"

/**
 * Where the menu bar's menus live on one screen, and how they move.
 *
 * Motion: components/GlassMorph (shared with every pop-up of glass), fitted
 * frame by frame to Apple's Liquid Glass — the menu leaves the item as a drop,
 * swells into the menu and focuses in; closing shrinks it back into a drop
 * that melts into the item; switching menus reshapes the same glass.
 *
 * The layer covers the screen *below* the bar, so the bar always gets its
 * own clicks and hover (a second click on the open item closes its menu, a
 * click on another item or moving onto it switches). The glass therefore
 * emerges from the bar's lower edge under the item and melts back into it.
 * A press anywhere else closes the menu. While open it takes the
 * keyboard: ↑/↓ move the highlight, ←/→ switch to the neighbouring menu,
 * Return chooses, Esc closes.
 */
PanelWindow {
    id: menuLayer

    required property ShellScreen modelData
    screen: modelData

    readonly property bool wanted: Menus.isOpen && Menus.screen === modelData.name
    /** Last opened menu, kept while the close animation plays. */
    property string shownId: ""

    anchors { top: true; left: true; right: true; bottom: true }
    // Below the bar: an input mask leaving the bar strip out didn't reach
    // the compositor, so the layer swallowed every click meant for the bar.
    margins.top: Tokens.bar.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-menu"
    // Hyprland hands the pointer to a layer that takes the keyboard when it
    // maps (or turns Exclusive), even with the cursor over the bar, so a
    // second click on the item went nowhere. Grabbing Exclusive for a moment
    // and then dropping to OnDemand keeps the keyboard here and makes
    // Hyprland re-pick the pointer target (simulateMouseMovement). Staying
    // Exclusive isn't an option: then every click goes to this layer.
    WlrLayershell.keyboardFocus: !wanted ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    property bool grabbing: false
    onWantedChanged: if (wanted) {
        grabbing = true;
        grabRelease.restart();
    }
    Timer {
        id: grabRelease
        interval: 60
        onTriggered: menuLayer.grabbing = false
    }
    // Stay mapped from the first open until the glass is back in the item.
    // `wanted || !settled` hid the window for one frame at the start of a
    // close (springs still resting at the menu), which dropped the glass
    // textures and made the menu flash and jump.
    visible: wanted || shownId.length > 0

    function componentFor(id) {
        switch (id) {
        case "sound": return soundMenu;
        case "network": return networkMenu;
        case "bluetooth": return bluetoothMenu;
        case "battery": return batteryMenu;
        case "system": return systemMenu;
        case "app": return appMenu;
        case "controlCenter": return controlCenterMenu;
        case "notifications": return notificationCenter;
        default: return id.startsWith("tray:") ? trayMenu : null;
        }
    }

    // --- Geometry --------------------------------------------------------------

    /**
     * Where the glass comes from and returns to: a sliver along the bar's
     * lower edge under the item (layer coordinates start at that edge).
     */
    readonly property rect itemRect: Qt.rect(Menus.anchorX, 0, Menus.anchorWidth, 4)

    readonly property real panelWidth: loader.item ? loader.item.implicitWidth : 0
    readonly property real panelHeight: loader.item ? loader.item.implicitHeight : 0
    /** Where the menu sits once open: under its item, pulled in from the screen edge. */
    readonly property rect panelRect: Qt.rect(
        // The screen's width, not the window's: a hidden layer has no size yet
        // when the first menu opens.
        Math.max(Tokens.menu.edgeMargin, Math.min(Menus.anchorX, modelData.width - panelWidth - Tokens.menu.edgeMargin)),
        Tokens.menu.gap, panelWidth, panelHeight)

    // A switch between menus (pointer tracking, ←/→) reshapes the same glass
    // (GlassMorph follows toRect) and lets the new content focus in again.
    Connections {
        target: Menus
        function onActiveChanged() {
            if (!Menus.active.length || Menus.screen !== menuLayer.modelData.name)
                return;
            const switching = menuLayer.shownId.length > 0 && menuLayer.shownId !== Menus.active;
            menuLayer.shownId = Menus.active;
            if (switching)
                morph.refocus();
        }
    }

    // --- Scene -------------------------------------------------------------------

    MouseArea {
        anchors.fill: parent
        onPressed: Menus.close()
    }

    GlassBackdrop {
        id: menuBackdrop
        screen: menuLayer.modelData
        origin: Qt.point(0, Tokens.bar.height)
        region: Qt.rect(menuLayer.panelRect.x, menuLayer.panelRect.y + Tokens.bar.height, menuLayer.panelWidth, menuLayer.panelHeight)
    }

    FocusScope {
        anchors.fill: parent
        focus: menuLayer.wanted

        Keys.onPressed: event => {
            const panel = loader.item;
            if (event.key === Qt.Key_Escape) {
                // A panel with levels (Control Center) steps back first.
                if (!(panel && panel.back && panel.back()))
                    Menus.close();
            }
            else if (event.key === Qt.Key_Down && panel)
                panel.move(1);
            else if (event.key === Qt.Key_Up && panel)
                panel.move(-1);
            else if (event.key === Qt.Key_Left)
                Menus.step(-1);
            else if (event.key === Qt.Key_Right)
                Menus.step(1);
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && panel)
                panel.activate();
            else
                return;
            event.accepted = true;
        }

        // The shared menu motion: out of the bar item as a drop, into the menu.
        GlassMorph {
            id: morph
            anchors.fill: parent
            open: menuLayer.wanted && menuLayer.shownId.length > 0
            fromRect: menuLayer.itemRect
            toRect: menuLayer.panelRect
            panelRadius: (loader.item && loader.item.panelRadius) || Tokens.radius.menu
            backdrop: menuBackdrop
            bare: !!(loader.item && loader.item.bare)
            onClosed: menuLayer.shownId = ""

            Loader {
                id: loader
                sourceComponent: menuLayer.componentFor(menuLayer.shownId)
            }
            // Where the panel sits moves after it's created (its width is
            // only known then): glass inside it re-maps itself onto the
            // backdrop through `track`, or it samples the old spot.
            Binding {
                target: loader.item
                property: "track"
                when: !!loader.item
                value: [menuLayer.panelRect.x, menuLayer.panelRect.y, menuLayer.panelWidth, menuLayer.panelHeight]
            }
        }
    }

    // --- Menus -------------------------------------------------------------------

    Component {
        id: networkMenu
        NetworkMenu {
            chrome: false
            backdrop: menuBackdrop
            onPasswordRequested: network => {
                Menus.close();
                Dialogs.askWifiPassword(network);
            }
        }
    }

    Component {
        id: bluetoothMenu
        BluetoothMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: batteryMenu
        BatteryMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: systemMenu
        SystemMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: notificationCenter
        NotificationCenter { backdrop: menuBackdrop }
    }

    Component {
        id: controlCenterMenu
        ControlCenter { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: appMenu
        AppMenu { chrome: false; backdrop: menuBackdrop }
    }

    Component {
        id: trayMenu
        TrayMenu { chrome: false; backdrop: menuBackdrop; itemId: menuLayer.shownId.slice(5) }
    }

    Component {
        id: soundMenu
        SoundMenu { chrome: false; backdrop: menuBackdrop }
    }
}
