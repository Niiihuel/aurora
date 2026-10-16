import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "core"
import "dialogs"

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

    WifiPasswordDialog {}
    ConfirmDialog {}

    // `qs ipc call aurora menu sound` opens a menu bar menu on the focused
    // screen (toggles if it's open); `closeMenu` closes any.
    IpcHandler {
        target: "aurora"
        function menu(id: string): void { Menus.request(id); }
        function closeMenu(): void { Menus.close(); }
        function activeMenu(): string { return Menus.active; }
    }
}
