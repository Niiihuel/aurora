-- Keyboard, pointer and touchpad.

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        accel_profile = "flat",
        repeat_rate = 40,
        repeat_delay = 400,
        numlock_by_default = false,
        touchpad = { natural_scroll = true },
    },
    cursor = {
        no_hardware_cursors = true,
        default_monitor = "DP-1", -- docked, start on the desk monitor
    },
    binds = { scroll_event_delay = 40 },
})
