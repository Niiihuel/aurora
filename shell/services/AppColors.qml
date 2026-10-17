pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Other programs wear aurora's colors: the terminal (kitty) and the KDE/Qt
 * apps (Dolphin, Okular… through kdeglobals) follow the appearance, the
 * accent and Reduce Transparency, and pick a change up while they're open.
 * The palettes are Apple's system colors (macOS dark and light); selection,
 * links and the cursor take the accent.
 *
 * kitty includes ~/.local/state/aurora/kitty-colors.conf and listens on
 * `unix:@kitty-aurora-<pid>` (see ~/dotfiles/configs/kitty/kitty.conf).
 */
Singleton {
    id: root

    readonly property bool dark: Settings.dark
    readonly property string accent: Tokens.accent.toString()
    readonly property bool clear: !Settings.reduceTransparency
    readonly property string kittyPath: Settings.stateDir + "/kitty-colors.conf"
    readonly property string kdePath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/kdeglobals"

    /** Write both and tell the open apps (debounced: the accent settles a moment after login). */
    function apply() {
        soon.restart();
    }
    onDarkChanged: apply()
    onAccentChanged: apply()
    onClearChanged: apply()

    readonly property var colors: dark ? {
        // macOS dark: systemGray6…3 for surfaces, the system colors and their brighter accessible variants.
        view: "#1c1c1e", window: "#2c2c2e", button: "#3a3a3c", tooltip: "#3a3a3c",
        ink: "#e5e5ea", dim: "#98989d",
        negative: "#ff453a", neutral: "#ff9f0a", positive: "#30d158", visited: "#bf5af2",
        ansi: ["#2c2c2e", "#ff453a", "#30d158", "#ffd60a", "#0a84ff", "#bf5af2", "#64d2ff", "#d1d1d6",
               "#636366", "#ff6961", "#31de4b", "#ffd426", "#409cff", "#da8fff", "#70d7ff", "#ffffff"],
        icons: "Papirus-Dark"
    } : {
        view: "#ffffff", window: "#f2f2f7", button: "#ffffff", tooltip: "#ffffff",
        ink: "#1d1d1f", dim: "#6e6e73",
        negative: "#ff3b30", neutral: "#ff9500", positive: "#34c759", visited: "#af52de",
        ansi: ["#1d1d1f", "#d70015", "#248a3d", "#a05a00", "#0040dd", "#8944ab", "#0071a4", "#8e8e93",
               "#636366", "#ff3b30", "#34c759", "#c98a00", "#007aff", "#af52de", "#32ade6", "#c7c7cc"],
        icons: "Papirus"
    }

    function kitty() {
        const p = colors;
        let out = "# Written by aurora (shell/services/AppColors.qml). Changes go there.\n"
            + `background ${p.view}\nforeground ${p.ink}\n`
            + `cursor ${accent}\ncursor_text_color ${p.view}\n`
            + `selection_background ${accent}\nselection_foreground #ffffff\nurl_color ${accent}\n`
            + `background_opacity ${clear ? 0.85 : 1}\n`;
        p.ansi.forEach((c, i) => out += `color${i} ${c}\n`);
        return out;
    }

    function kde() {
        const p = colors;
        const rgb = hex => [1, 3, 5].map(i => parseInt(hex.substr(i, 2), 16)).join(",");
        const group = (name, bg, alt, fg) => `[Colors:${name}]\n`
            + `BackgroundAlternate=${rgb(alt)}\nBackgroundNormal=${rgb(bg)}\n`
            + `DecorationFocus=${rgb(accent)}\nDecorationHover=${rgb(accent)}\n`
            + `ForegroundActive=${rgb(accent)}\nForegroundInactive=${rgb(p.dim)}\nForegroundLink=${rgb(accent)}\n`
            + `ForegroundNegative=${rgb(p.negative)}\nForegroundNeutral=${rgb(p.neutral)}\nForegroundNormal=${rgb(fg || p.ink)}\n`
            + `ForegroundPositive=${rgb(p.positive)}\nForegroundVisited=${rgb(p.visited)}\n\n`;
        const font = "Inter,10,-1,5,50,0,0,0,0,0";
        return "# Written by aurora (shell/services/AppColors.qml). Changes go there.\n"
            + group("Button", p.button, p.window)
            + group("Complementary", p.window, p.view)
            + group("Header", p.window, p.view)
            + group("Header][Inactive", p.window, p.view)
            + group("Selection", accent, accent, "#ffffff")
            + group("Tooltip", p.tooltip, p.window)
            + group("View", p.view, p.window)
            + group("Window", p.window, p.view)
            + `[General]\nColorScheme=aurora\nName=aurora\nfont=${font}\nmenuFont=${font}\ntoolBarFont=${font}\n\n`
            + "[KDE]\nwidgetStyle=Breeze\ncontrast=4\n\n"
            + `[Icons]\nTheme=${p.icons}\n\n`
            + `[WM]\nactiveBackground=${rgb(p.window)}\nactiveForeground=${rgb(p.ink)}\n`
            + `inactiveBackground=${rgb(p.window)}\ninactiveForeground=${rgb(p.dim)}\n`;
    }

    Timer {
        id: soon
        interval: 800
        onTriggered: {
            kittyFile.setText(root.kitty());
            kdeFile.setText(root.kde());
            // Every open kitty window, then every running KDE app (0 = the palette changed).
            Quickshell.execDetached(["sh", "-c",
                "for s in $(grep -o '@kitty-aurora-[0-9]*' /proc/net/unix | sort -u); do "
                + "kitty @ --to \"unix:$s\" set-colors --all --configured \"$1\"; "
                + "kitty @ --to \"unix:$s\" set-background-opacity --all \"$2\"; done; "
                + "dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0",
                "_", root.kittyPath, root.clear ? "0.85" : "1"]);
        }
    }

    FileView {
        id: kittyFile
        path: root.kittyPath
        printErrors: false
    }
    FileView {
        id: kdeFile
        path: root.kdePath
        printErrors: false
    }
}
