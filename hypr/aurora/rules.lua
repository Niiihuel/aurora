-- How windows behave.

-- Apps don't maximize themselves; the layout decides their size.
hl.window_rule({ name = "no-self-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- XWayland drag-and-drop ghosts (no class, no title) must not take focus.
hl.window_rule({
    name = "xwayland-drag-ghosts",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Dialogs and small utilities float, as they would on a Mac.
hl.window_rule({
    name = "float-dialogs",
    match = { class = "(pavucontrol|nm-connection-editor|blueman-manager|org.kde.polkit-kde-authentication-agent-1|xdg-desktop-portal-gtk)" },
    float = true,
})
hl.window_rule({
    name = "float-file-pickers",
    match = { title = "(Open File|Save File|Save As|Choose Files|Open Folder)" },
    float = true,
})
hl.window_rule({
    name = "float-utilities",
    match = { class = "(Ghosttype-app|[Ss]potify|io.github.Qalculate.qalculate-qt)" },
    float = true,
})

-- Watching something full screen keeps the screen awake.
hl.window_rule({ name = "awake-while-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })
