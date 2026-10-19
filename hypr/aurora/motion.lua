-- Motion: the shell's own springs (shell/core/Motion.qml), so a window moves
-- the way a menu does. Hyprland integrates them as real physics, in real
-- time, and keeps the velocity when a move is interrupted. A preset's
-- duration d (settle time, seconds) and bounce b (0–1) become
-- stiffness (2π / d)² and damping 4π(1 − b) / d, with mass 1.

local function spring(name, d, b)
    hl.curve(name, { type = "spring", mass = 1, stiffness = (2 * math.pi / d) ^ 2, dampening = 4 * math.pi * (1 - b) / d })
end
spring("smooth", 0.40, 0)  -- Motion.smooth: most things
spring("dismiss", 0.20, 0) -- Motion.dismiss: going away is quicker than arriving
spring("swift", 0.28, 0)   -- desktops: crossed all the time, so quicker than smooth

local function animate(leaf, curve, style)
    hl.animation({ leaf = leaf, enabled = true, speed = 1, spring = curve, style = style })
end
local function still(leaf)
    hl.animation({ leaf = leaf, enabled = false })
end

-- Settings › Accessibility › Reduce Motion: nothing moves or scales, things
-- only fade (the Settings switch reloads Hyprland).
local function reduceMotion()
    local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local f = io.open(state .. "/aurora/settings.json", "r")
    if not f then
        return false
    end
    local json = f:read("*a")
    f:close()
    return json:match('"reduceMotion"%s*:%s*true') ~= nil
end

hl.config({ animations = { enabled = true } })
animate("global", "smooth")
still("border") -- the rim plugin draws the edge; the border is clear
still("borderangle")

if reduceMotion() then
    still("windows")
    still("layers")
    animate("workspaces", "swift", "fade")
    animate("fadeOut", "dismiss")
    return
end

-- A window opens like a macOS window: it grows in from a little smaller as
-- it fades in, and leaves the same way, faster.
animate("windows", "smooth")
animate("windowsIn", "smooth", "popin 94%")
animate("windowsOut", "dismiss", "popin 94%")
animate("fadeOut", "dismiss")
-- Desktops slide side by side, like Spaces; the hidden ones fade over.
animate("workspaces", "swift", "slide")
animate("specialWorkspace", "smooth", "fade")
-- Other programs' layers just fade (aurora's animate themselves; see look.lua).
animate("layers", "smooth", "fade")
