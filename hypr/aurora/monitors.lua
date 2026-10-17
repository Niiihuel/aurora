-- This machine's screens: the laptop panel (eDP-2) takes Hyprland's own
-- choice; the desk monitor sits to its right; HDMI mirrors the panel.

hl.monitor({ output = "DP-1", mode = "2560x1440@280", position = "2560x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-2" })

-- Desktops 1–5 belong to the desk monitor, starting on 1, so a docked login
-- doesn't land on whatever number the panel would get.
for n = 1, 5 do
    hl.workspace_rule({ workspace = tostring(n), monitor = "DP-1", default = n == 1 })
end
