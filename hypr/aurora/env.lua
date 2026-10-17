-- Session environment.

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")

-- Apps pick their GPU's video driver themselves; forcing NVIDIA's for all of
-- them breaks the AMD default on this PRIME laptop (use nvidia-offload per app).
hl.env("__GL_GSYNC_ALLOWED", "0")
hl.env("__GL_VRR_ALLOWED", "0")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Qt apps (Dolphin, Okular…) read their colors from kdeglobals through the
-- KDE platform theme.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
