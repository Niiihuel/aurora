-- Window chrome: gaps, corners, the glass rim's room, shadow and blur.

hl.config({
    general = {
        layout = "dwindle",
        gaps_in = 6,
        gaps_out = 12,
        -- The rims plugin (plugins/rims) draws liquid glass in the border's
        -- place, so the border is only room: as wide as the rim, and clear.
        border_size = 4,
        ["col.active_border"] = "rgba(00000000)",
        ["col.inactive_border"] = "rgba(00000000)",
        resize_on_border = true,
    },
    decoration = {
        rounding = 12,
        rounding_power = 4, -- continuous corners, like Apple's
        -- macOS's window shadow: wide, soft, a little below, lighter without focus.
        shadow = {
            enabled = true,
            range = 40,
            render_power = 2,
            offset = { 0, 10 },
            color = 0x55000000,
            color_inactive = 0x30000000,
        },
        -- The material behind translucent windows (the terminal).
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            vibrancy = 0.17,
            noise = 0.01,
            new_optimizations = true,
        },
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        -- A blanked panel wakes on any input, not only through hypridle.
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        -- If the lock screen dies while locked, its restart takes over
        -- (aurora's lock relocks itself on start).
        allow_session_lock_restore = true,
    },
})

-- aurora's surfaces animate themselves (a menu pops out of its item as a
-- glass drop); Hyprland's own layer animation on top would fight it.
hl.layer_rule({ name = "aurora-own-motion", match = { namespace = "^aurora-" }, no_anim = true })
