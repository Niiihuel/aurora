-- Hidden desktops (Hyprland's special workspaces): each one slides over the
-- desktop on screen and away again. Some apps always open in one, and a key
-- hides the focused window in one or brings it back. binds.lua binds them.

local spaces = {}

-- Hide the focused window in special:<name>; if it's already there, bring it
-- back to the desktop on screen. One key does both.
function spaces.toggle(name)
    return function()
        local w = hl.get_active_window()
        if not w then
            return
        end
        local window = "address:" .. w.address
        if w.workspace and w.workspace.name == "special:" .. name then
            hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_monitor().active_workspace.id, window = window }))
        else
            hl.dispatch(hl.dsp.window.move({ workspace = "special:" .. name, follow = false, window = window }))
        end
    end
end

-- Where some apps always open.
local homes = {
    stash = { "[Ss]potify", "Ghosttype-app" },
    discord = { "discord" },
}
for space, classes in pairs(homes) do
    for _, class in ipairs(classes) do
        hl.window_rule({ name = "opens-in-" .. space .. "-" .. class, match = { class = class }, workspace = "special:" .. space })
    end
end

-- Hidden desktops of the user's own, each with a Super+<key> to show it and
-- Super+Shift+<key> to hide a window there (Settings lists them, read-only).
spaces.own = {
    { id = "discord", key = "A" },
}

return spaces
