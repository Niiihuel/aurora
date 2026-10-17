import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../components/menu"

/**
 * The frontmost app's menu, from its name in the menu bar: new windows (and
 * the app's own desktop actions), the window's full-screen and floating
 * state, moving it to another desktop, minimizing, closing it, and quitting
 * the app (closing every window it has). It acts on the window that was
 * frontmost when it opened. "Move to desktop" opens in place under a back
 * row, like other submenus; Esc steps back out.
 */
MenuPanel {
    id: root

    panelWidth: 220

    // Taken once: whatever gets focus while the menu is open isn't the target.
    property HyprlandToplevel window: null
    Component.onCompleted: {
        window = Hyprland.activeToplevel;
        Hyprland.refreshToplevels();
    }

    readonly property var info: window && window.lastIpcObject ? window.lastIpcObject : ({})
    readonly property string appId: window && window.wayland ? window.wayland.appId : ""
    readonly property var entry: appId.length ? (DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId)) : null
    readonly property string appName: entry && entry.name ? entry.name : appId
    readonly property string target: window ? address(window) : ""

    function address(t) {
        return t.address.startsWith("0x") ? t.address : "0x" + t.address;
    }

    /** Other desktops on this window's screen, then a new one after the last. */
    readonly property var desktops: {
        const mon = window ? window.monitor : null;
        const here = window && window.workspace ? window.workspace.id : -1;
        const ids = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === mon).map(w => w.id).sort((a, b) => a - b);
        return { others: ids.filter(id => id !== here), next: Math.max(0, ...ids) + 1 };
    }

    property bool moving: false

    function back() {
        if (!moving)
            return false;
        moving = false;
        highlighted = null;
        return true;
    }

    function dispatch(action, args) {
        Hyprland.dispatch(`hl.dsp.window.${action}({ ${args ? args + ", " : ""}window = "address:${root.target}" })`);
    }

    // --- The app ---------------------------------------------------------------

    MenuItem {
        visible: !root.moving && !!root.entry
        text: I18n.tr("app.newWindow")
        reserveMark: true
        onTriggered: root.entry.execute()
    }

    Repeater {
        // The app's own "new window" action would repeat the row above.
        model: !root.moving && root.entry ? root.entry.actions.filter(a => a.id !== "new-window") : []
        delegate: MenuItem {
            required property DesktopAction modelData
            text: modelData.name
            reserveMark: true
            onTriggered: modelData.execute()
        }
    }

    MenuSeparator { visible: !root.moving && !!root.entry }

    // --- The window ------------------------------------------------------------

    MenuItem {
        visible: !root.moving
        text: I18n.tr("app.fullScreen")
        reserveMark: true
        checked: (root.info.fullscreen ?? 0) > 0
        onTriggered: root.dispatch("fullscreen")
    }

    MenuItem {
        visible: !root.moving
        text: I18n.tr("app.float")
        reserveMark: true
        checked: !!root.info.floating
        onTriggered: root.dispatch("float", `action = "toggle"`)
    }

    MenuItem {
        visible: !root.moving
        text: I18n.tr("app.moveTo")
        reserveMark: true
        hasSubmenu: true
        closeOnTrigger: false
        onTriggered: {
            root.moving = true;
            root.highlighted = null;
        }
    }

    MenuItem {
        visible: !root.moving
        text: I18n.tr("app.minimize")
        reserveMark: true
        onTriggered: root.dispatch("move", `workspace = "special:minimized", follow = false`)
    }

    MenuSeparator { visible: !root.moving }

    MenuItem {
        visible: !root.moving
        text: I18n.tr("app.closeWindow")
        reserveMark: true
        onTriggered: root.dispatch("close")
    }

    MenuItem {
        visible: !root.moving
        text: I18n.tr("app.quit", { app: root.appName })
        reserveMark: true
        onTriggered: {
            for (const t of Hyprland.toplevels.values)
                if (t.wayland && t.wayland.appId === root.appId)
                    Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${root.address(t)}" })`);
        }
    }

    // --- Move to desktop -------------------------------------------------------

    MenuItem {
        visible: root.moving
        text: I18n.tr("app.moveTo")
        glyph: Glyphs.chevronBack
        closeOnTrigger: false
        onTriggered: root.back()
    }

    MenuSeparator { visible: root.moving }

    Repeater {
        model: root.moving ? root.desktops.others : []
        delegate: MenuItem {
            required property int modelData
            text: I18n.tr("app.desktop", { n: modelData })
            onTriggered: root.dispatch("move", `workspace = ${modelData}, follow = false`)
        }
    }

    MenuItem {
        visible: root.moving
        text: I18n.tr("app.newDesktop")
        onTriggered: root.dispatch("move", `workspace = ${root.desktops.next}, follow = false`)
    }
}
