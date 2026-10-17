-- Keyboard shortcuts. Every action has an id and its default keys here; the
-- user's changes live in ~/.config/hypr/keybinds.conf, which aurora's
-- Settings (Keyboard) writes — data only, never Lua:
--
--   set <TAB> <action id> <TAB> <keys>                (empty keys = off)
--   run <TAB> <keys> <TAB> <name> <TAB> <command>      (one of their own; empty keys = off)
--
-- Each bind carries its id as the description, so Settings reads what is
-- really bound back from `hyprctl binds -j`. A changed shortcut whose keys
-- don't parse falls back to the default instead of leaving the action
-- unbound. `fixed` actions are listed in Settings but can't be changed there
-- (media keys, the mouse, and the switcher, which commits when Alt is let go).

local spaces = require("aurora.spaces")

local home = os.getenv("HOME")
local shell = home .. "/projects/personal/aurora/shell"

-- aurora does the work in-process (OSD, switcher, editor…) through global shortcuts.
local function aurora(name)
    return hl.dsp.global("aurora:" .. name)
end
local function aurora_now(name)
    return function()
        hl.dispatch(hl.dsp.global("aurora:" .. name))
    end
end
local function ipc(args)
    return hl.dsp.exec_cmd("qs ipc -p " .. shell .. " call aurora " .. args)
end

local actions = {
    -- Windows
    { id = "window.close", keys = "SUPER + Q", run = hl.dsp.window.close() },
    { id = "window.kill", keys = "SUPER + SHIFT + Q", run = hl.dsp.window.kill() },
    { id = "window.fullscreen", keys = "SUPER + F", run = hl.dsp.window.fullscreen() },
    { id = "window.float", keys = "SUPER + T", run = hl.dsp.window.float({ action = "toggle" }) },
    { id = "window.minimize", keys = "SUPER + M", run = spaces.toggle("minimized") },
    { id = "window.minimized", keys = "SUPER + SHIFT + M", run = hl.dsp.workspace.toggle_special("minimized") },
    { id = "window.drag", keys = "SUPER + mouse:272", run = hl.dsp.window.drag(), opts = { mouse = true }, fixed = true },
    { id = "window.resize", keys = "SUPER + mouse:273", run = hl.dsp.window.resize(), opts = { mouse = true }, fixed = true },

    -- The window switcher: Hyprland sees Alt let go (by keycode, 64 = left Alt:
    -- a keysym never fires on release), aurora draws the glass. The release
    -- doesn't consume, so apps still get their Alt.
    { id = "switcher.next", keys = "ALT + Tab", run = aurora_now("switcherNext"), fixed = true },
    { id = "switcher.previous", keys = "ALT + SHIFT + Tab", run = aurora_now("switcherPrevious"), fixed = true },
    { id = "switcher.nextApp", keys = "ALT + grave", run = aurora_now("switcherNextApp"), fixed = true },
    { id = "switcher.cancel", keys = "ALT + Escape", run = aurora_now("switcherCancel"), fixed = true },
    { id = "switcher.commit", keys = "ALT + code:64", run = aurora_now("switcherCommit"), opts = { release = true, non_consuming = true }, fixed = true },

    -- Desktops
    { id = "workspace.previous", keys = "SUPER + Left", run = hl.dsp.focus({ workspace = "r-1" }) },
    { id = "workspace.next", keys = "SUPER + Right", run = hl.dsp.focus({ workspace = "r+1" }) },
    { id = "workspace.scrollPrevious", keys = "SUPER + mouse_up", run = hl.dsp.focus({ workspace = "r-1" }), fixed = true },
    { id = "workspace.scrollNext", keys = "SUPER + mouse_down", run = hl.dsp.focus({ workspace = "r+1" }), fixed = true },
}

-- Super+1…0: desktop 1…10; with Shift, the window goes there.
for n = 1, 10 do
    table.insert(actions, { id = "workspace.go." .. n, keys = "SUPER + " .. n % 10, run = hl.dsp.focus({ workspace = n }) })
end
for n = 1, 10 do
    table.insert(actions, { id = "workspace.send." .. n, keys = "SUPER + SHIFT + " .. n % 10, run = hl.dsp.window.move({ workspace = n, follow = false }) })
end

for _, a in ipairs({
    -- Hidden desktops (spaces.lua)
    { id = "special.private", keys = "SUPER + P", run = hl.dsp.workspace.toggle_special("private") },
    { id = "special.privateSend", keys = "SUPER + SHIFT + P", run = spaces.toggle("private") },
    { id = "special.stash", keys = "SUPER + S", run = hl.dsp.workspace.toggle_special("stash") },
    { id = "special.stashSend", keys = "SUPER + SHIFT + W", run = spaces.toggle("stash") },

    -- Apps
    { id = "app.launcher", keys = "SUPER + Space", run = ipc("launcher apps") },
    { id = "app.clipboard", keys = "SUPER + V", run = ipc("launcher clipboard") },
    { id = "app.terminal", keys = "SUPER + Return", run = hl.dsp.exec_cmd("kitty") },
    { id = "app.files", keys = "SUPER + E", run = hl.dsp.exec_cmd("dolphin") },
    { id = "app.colorPicker", keys = "SUPER + SHIFT + C", run = hl.dsp.exec_cmd("hyprpicker -a") },

    -- Screenshots (freeze, select, mark up) and recording
    { id = "screenshot.full", keys = "Print", run = aurora("screenshot") },
    { id = "screenshot.monitor", keys = "SHIFT + Print", run = aurora("screenshotMonitor") },
    { id = "screenshot.region", keys = "SUPER + SHIFT + S", run = aurora("screenshot") },
    { id = "screenshot.monitorWindows", keys = "SUPER + SHIFT + F", run = aurora("screenshotMonitor") },
    { id = "screen.record", keys = "SUPER + D", run = aurora("capture") },

    -- System
    { id = "system.lock", keys = "SUPER + L", run = hl.dsp.exec_cmd("qs ipc -p " .. shell .. "/lock.qml call lock lock") },
    { id = "system.wallpaperPicker", keys = "SUPER + C", run = aurora("wallpaperPicker") },
    { id = "system.wallpaperNext", keys = "SUPER + B", run = aurora("wallpaperNext") },

    -- Volume, brightness and media keys: aurora changes the level and shows its HUD.
    { id = "media.volumeUp", keys = "XF86AudioRaiseVolume", run = aurora("volumeUp"), opts = { locked = true, repeating = true }, fixed = true },
    { id = "media.volumeDown", keys = "XF86AudioLowerVolume", run = aurora("volumeDown"), opts = { locked = true, repeating = true }, fixed = true },
    { id = "media.mute", keys = "XF86AudioMute", run = aurora("volumeMute"), opts = { locked = true }, fixed = true },
    { id = "media.brightnessUp", keys = "XF86MonBrightnessUp", run = aurora("brightnessUp"), opts = { locked = true, repeating = true }, fixed = true },
    { id = "media.brightnessDown", keys = "XF86MonBrightnessDown", run = aurora("brightnessDown"), opts = { locked = true, repeating = true }, fixed = true },
    { id = "media.playPause", keys = "XF86AudioPlay", run = aurora("mediaToggle"), opts = { locked = true }, fixed = true },
    { id = "media.next", keys = "XF86AudioNext", run = aurora("mediaNext"), opts = { locked = true }, fixed = true },
    { id = "media.previous", keys = "XF86AudioPrev", run = aurora("mediaPrevious"), opts = { locked = true }, fixed = true },
}) do
    table.insert(actions, a)
end

-- The user's own hidden desktops: shown and filled with their keys.
for _, space in ipairs(spaces.own) do
    table.insert(actions, { id = "space.show." .. space.id, keys = "SUPER + " .. space.key, run = hl.dsp.workspace.toggle_special(space.id), fixed = true })
    table.insert(actions, { id = "space.send." .. space.id, keys = "SUPER + SHIFT + " .. space.key, run = spaces.toggle(space.id), fixed = true })
end

-- --- The user's changes --------------------------------------------------------

local changed, own = {}, {}
local file = io.open(home .. "/.config/hypr/keybinds.conf", "r")
if file then
    for line in file:lines() do
        local id, keys = line:match("^set\t([^\t]+)\t([^\t]*)$")
        if id then
            changed[id] = keys
        else
            local okeys, name, command = line:match("^run\t([^\t]*)\t([^\t]*)\t(.+)$")
            if okeys then
                table.insert(own, { keys = okeys, name = name, command = command })
            end
        end
    end
    file:close()
end

local function bind(keys, run, opts, description)
    local o = { description = description }
    for k, v in pairs(opts or {}) do
        o[k] = v
    end
    return hl.bind(keys, run, o)
end

for _, a in ipairs(actions) do
    local keys = a.keys
    if not a.fixed and changed[a.id] ~= nil then
        keys = changed[a.id]
    end
    if keys ~= "" and not bind(keys, a.run, a.opts, a.id) and keys ~= a.keys then
        bind(a.keys, a.run, a.opts, a.id)
    end
end

-- run.<n> is the line's place among the user's own, off ones included.
for i, o in ipairs(own) do
    if o.keys ~= "" then
        bind(o.keys, hl.dsp.exec_cmd(o.command), nil, "run." .. i)
    end
end

-- While Settings records a shortcut it switches to this empty submap, so the
-- keys reach it instead of firing, and back when done. Should Settings die
-- mid-recording, Super+Alt+Escape returns.
hl.define_submap("aurora-record", function()
    hl.bind("SUPER + ALT + Escape", hl.dsp.submap("reset"))
end)
