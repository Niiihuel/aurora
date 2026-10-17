-- What starts with the session (once per Hyprland start, not on reloads).

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- The session's user services: polkit prompts, night light, inactivity.
    -- aurora writes hypridle's config and restarts it when it starts.
    hl.exec_cmd("systemctl --user start hyprland-session.target hyprpolkitagent hyprsunset hypridle")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 20")

    -- The wallpaper daemon puts back the last image itself.
    hl.exec_cmd("awww-daemon")
    -- Clipboard history, which the launcher (Super+V) reads.
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- The shell, its lock screen and the window rims, kept running.
    hl.exec_cmd(home .. "/projects/personal/aurora/scripts/aurora-session.sh")

    -- Start on desktop 1, on the desk monitor when docked (focusing a monitor
    -- that isn't there fails quietly).
    pcall(function()
        hl.dispatch(hl.dsp.focus({ monitor = "DP-1" }))
    end)
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
