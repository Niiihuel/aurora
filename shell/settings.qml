import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "dialogs"
import "settings"

/**
 * aurora's Settings app, its own process (`scripts/aurora-settings [page]`
 * starts it or brings it to a page). Closing the window ends it.
 */
ShellRoot {
    FloatingWindow {
        id: win
        title: I18n.tr("settings.title")
        implicitWidth: 940
        implicitHeight: 640
        minimumSize: Qt.size(760, 520)
        // SettingsApp paints the background, leaving the sidebar's glass see-through.
        color: "transparent"
        // Closed: end the app. Not at once — a hot reload hides the old
        // window too, and this timer dies with it before it fires.
        onVisibleChanged: if (!visible) quitSoon.start()
        Timer {
            id: quitSoon
            interval: 500
            onTriggered: if (!win.visible) Qt.quit()
        }

        // Cmd+W on a Mac; the window has no traffic lights (no window in this
        // desktop does: Hyprland draws no title bars).
        Shortcut {
            sequences: ["Ctrl+W", StandardKey.Close]
            onActivated: Qt.quit()
        }

        SettingsApp {
            id: app
            anchors.fill: parent
            window: win
            page: Quickshell.env("AURORA_SETTINGS_PAGE") || "wifi"
        }
    }

    // The accent follows the wallpaper here too (as in shell.qml).
    Binding {
        target: WallpaperAccent
        property: "source"
        value: Quickshell.screens.length ? Wallpaper.pathFor(Quickshell.screens[0].name) : ""
    }

    // Joining a secured network from the Wi-Fi page asks here.
    WifiPasswordDialog {}
    ConfirmDialog {}

    IpcHandler {
        target: "settings"
        function open(page: string): void {
            if (page.length)
                app.page = page;
        }
    }
}
