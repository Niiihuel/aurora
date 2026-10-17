-- aurora's Hyprland config. Home Manager links this file and the aurora/
-- folder next to it into ~/.config/hypr; everything the shell writes at
-- runtime (keybinds.conf, hypridle.conf) lives there as plain files, never
-- in this repo.

require("aurora.env")
require("aurora.monitors")
require("aurora.input")
require("aurora.look")
require("aurora.motion")
require("aurora.rules")
require("aurora.spaces")
require("aurora.binds")
require("aurora.start")

-- This machine's own additions, outside the repo: ~/.config/hypr/private.lua,
-- and GhostType's hotkey (the app writes ~/.config/hypr/ghosttype.lua).
pcall(require, "private")
pcall(require, "ghosttype")
