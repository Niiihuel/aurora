import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "core"
import "dialogs"
import "launcher"
import "notifications"
import "osd"
import "services"

/**
 * aurora's shell entry point. Sections are added here as they are built; see
 * the README roadmap. Today: the menu bar on every screen.
 */
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: MenuBar {}
    }

    Variants {
        model: Quickshell.screens
        delegate: MenuLayer {}
    }

    // The accent follows the main screen's wallpaper (Settings.accent overrides).
    Binding {
        target: WallpaperAccent
        property: "source"
        value: Quickshell.screens.length ? Wallpaper.pathFor(Quickshell.screens[0].name) : ""
    }

    Banners {}
    Launcher { id: launcher }
    Osd {}

    WifiPasswordDialog {}
    ConfirmDialog {}

    // `qs ipc call aurora menu sound` opens a menu bar menu on the focused
    // screen (toggles if it's open); `closeMenu` closes any.
    IpcHandler {
        target: "aurora"
        function menu(id: string): void { Menus.request(id); }
        function closeMenu(): void { Menus.close(); }
        // `launcher apps` / `launcher clipboard`: open that mode (or close it if it's showing).
        function launcher(mode: string): void { launcher.toggle(mode.length ? mode : "apps"); }
        // `controlCenter network` opens Control Center on that page ("" for the grid).
        function controlCenter(page: string): void { Menus.page = page; Menus.request("controlCenter"); }
        function activeMenu(): string { return Menus.active; }
        function accent(): string { return Tokens.accent.toString(); }
    }
}
