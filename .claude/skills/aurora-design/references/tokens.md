# aurora design tokens

These are the starting values. They live in code in the `Tokens` and `Motion` singletons; this file explains them. When you tune a value with the user, update both the singleton and this file.

Units: logical pixels = points (Hyprland logical px; the laptop panel is 2880×1800 at scale 2 → 1440×900 pt).

## Type

Text content comes from `I18n.tr` (see `i18n.md`); dates and numbers use `I18n.locale`.

- Family: **Inter** (open, metrics close to SF Pro). SF Pro's license only covers Apple platforms — don't install or reference it. Inter Display for sizes ≥ 20 pt if it reads better.
- Scale: use the macOS text styles from `hig-macos.md` §6 verbatim (Body 13/16, Callout 12/15, Subheadline 11/14, Footnote 10/13, Headline 13 bold, Title 3 15/20…).
- Numbers that change (clock, percentages, timers) use tabular figures (`font.features: { "tnum": 1 }`) so they don't jitter.

## Color (semantic)

Dark appearance first; light mirrors it.

| Token | Dark | Light |
|---|---|---|
| label | `#FFFFFF` @ 85% | `#000000` @ 85% |
| secondaryLabel | `#FFFFFF` @ 55% | `#000000` @ 50% |
| tertiaryLabel | `#FFFFFF` @ 25% | `#000000` @ 26% |
| quaternaryLabel | `#FFFFFF` @ 10% | `#000000` @ 10% |
| separator | `#FFFFFF` @ 10% | `#000000` @ 10% |
| accent (default blue) | `#0A84FF` | `#007AFF` |
| destructive | `#FF453A` | `#FF3B30` |
| success | `#30D158` | `#34C759` |
| warning | `#FFD60A` | `#FFCC00` |

Accent is a user setting: empty (the default) follows the wallpaper — `core/WallpaperAccent.qml` runs Quickshell's `ColorQuantizer` on the main screen's wallpaper and `core/accent.mjs` picks the dominant 30° hue family, makes it vivid (S 0.6–0.9) and darkens it until white labels reach 3.5:1 (Apple's blue is 3.6:1); a grey wallpaper keeps the blue. A "#RRGGBB" in Settings fixes it. Test the picker with `node shell/core/accent.test.mjs` (also a flake check). Template icons and labels on glass use label/secondaryLabel, never a raw hex.

## Glass presets

The material comes from `glass.frag` (limn's optics: a superellipse bezel whose exponent follows the band — a quarter circle for wide bezels (panels, modules: the whole band visibly lenses) and quartic for a knob's narrow one (flat until the edge, or the label under it ghosts into the rim), refraction eta 1/1.5, 5-tap bend, chromatic dispersion, CSS saturate 2.2, tint veil, a one-pixel hairline plus a soft specular band under it, both lit from the top-left, and a faint inner dark line).

| Preset | Tint | Blur radius | Refraction | Dispersion | Use |
|---|---|---|---|---|---|
| regular.dark | `#262628` @ 48% | 8 | 32 (large) / 14 (small) | 0.5 | menus, panels, banners (the Control Center panel too) |
| module | the panel's veil plus a light wash: `#424245` @ 52% (dark) / `#FAFAFB` @ 70% (light) | 8 | 14, bezel 12 | 0.5 | Control Center modules: lighter platters on the panel, each lensing at its own rim |
| regular.light | `#F5F5F7` @ 55% | 8 | same | 0.5 | light appearance |
| clear | 15–25% | 4 | 32 | 0.6 | over media only (+35% dim on bright backdrops) |
| bar | user slider 0–60% | 8 | 14 | 0.4 | the menu bar itself |
| knob | white @ 12% (dark) / 50% (light) | sharp | 4, bezel 6 | 0 | a control's knob at rest; refracts the control's hidden "selected" copy |
| lens | white @ 16% / 30% | sharp | 10, bezel 7 | 0.8 | a knob while lifted: magnify 1.1, flat middle, bent rim |
| rim | `#262628` @ 15% | sharp | 8, bezel = rim | 0.4 | window rims (`plugins/rims`, Hyprland): 4 pt wide (`general.border_size`), saturation 2.0, edge light 1.1 focused / 0.4 the rest |

`bezel` limits the bending band to a rim (points). Without it a capsule's bezel is its whole height and text under it duplicates into ghost rows. `magnify` zooms the middle of what's refracted.

Rim light (measured 2026-10-17 on Apple's dark pill in WWDC25 "Meet Liquid Glass" ~668 s, and the HIG's regular-over-dark circle): the light sits top-left; the hairline mixes ~0.55 white where the rim faces it, ~0.10 along the sides, ~0.08 on the far side (Apple's top edge is ~2.5× the sides, the bottom barely there — never a uniform outline). Under it a specular band fades exponentially over 0.3 × bezel (Apple's over ~4% of the shape), peaking at ~0.12 facing the light, ~0.03 elsewhere. Shadow under a light pill measured ~6% darkening over ~35% of its height, offset down — Apple's `0 10 40` holds.

Shadow under glass (Apple's): `0 10px 40px` black at 20% (dark) / 10% (light). Draw it with `RectangularShadow`, never a layer effect on a resizing item.

Window shadow (Hyprland `decoration.shadow`): range 40, render_power 2, offset `0 10`, black at 33% on the focused window and 19% on the rest.

Reduce Transparency: replace glass with an opaque `#1C1C1E` (dark) / `#F2F2F7` (light) fill and keep the hairline.

## Radii and spacing

- Spacing scale: 2, 4, 6, 8, 12, 16, 20, 24, 32.
- Menu bar: height 24; item horizontal padding 8; icon size 16; gap between extras 4–8.
- Menus: corner radius 12, inner padding 6, item height 24, item highlight radius 6 (concentric: 12 − 6), separator inset 10.
- Control Center: tiles radius 16, padding 10, panel radius 26 (= 16 + 10, concentric), tile gap 10. Modules pop in with the panel: scale 0.88 → 1 and fade on `snappy`, each row 35 ms after the one above, starting at `menuPhases.focusStart`.
- Banners (notifications): radius 20, padding 12. Notification Center: a panel of regular glass (radius 26 = 16 + 10) with the cards, the Clear All capsule and the calendar as `module` platters of radius 16, padding 10, overlay scroll bar over the list. Clear All: cards slide off right (260 ms, InCubic, 35 ms apart); halfway out each row folds (180 ms) so the rest move up and the panel shrinks behind them; dismissed only at the end.
- Always derive nested radii concentrically: inner = outer − inset.

## Motion

Apple's SwiftUI presets expressed as springs (duration ≈ perceptual settle time, bounce 0–1):

| Preset | Duration | Bounce | Use |
|---|---|---|---|
| smooth | 0.40 s | 0 | most transitions, panels, menus opening |
| snappy | 0.30 s | 0.15 | direct manipulation, toggles, glass lift |
| bouncy | 0.45 s | 0.30 | rare, playful confirmation |
| dismiss | 0.20 s | 0 | closing menus/panels (faster than opening) |
| hover | 0.12 s ease-out | — | highlight capsules in the bar and menus |
| press | 0.30 s | 0.35 | interactive glass under a press; scale ×1.075, highlight in 120 ms / out 300 ms |
| land | 0.42 s | 0.55 | a lifted knob settling back (Glass `releasePreset`): squashes ~6% under its rest size, rebounds ~2% over, settled ~0.75 s after release |

`land` and the knobs were measured on Apple's segmented control (Liquid Glass adoption guide video, 30 fps, 2026-10-17): the lifted knob is 1.30× wide / 1.37× tall and keeps that size while the finger holds; on release the position runs a snappy spring (50% at ~65 ms, 90% at ~170 ms, ~3% overshoot) while the lift relaxes on `land` from the moment of release, so the knob squashes into place as it arrives — never fat-then-deflating after a pause. aurora's knobs lift while the travel is still more than 45% of a segment (or half a switch track) away and land from there; the switch's lens is ~1.45× the track's height but ~0.72 of its width, corners a little flatter than a capsule's (WWDC25 "Meet Liquid Glass", ~250 s; Apple's measure ~0.38 of the height read as square at 22 pt, so aurora keeps 0.45). The switch knob moves as a drop: its two edges ride different springs (leading edge `snappy`, trailing `smooth`), stretching ~14% at ~110 ms and gathering back by ~450 ms — the user's call on 2026-10-17 ("más liquid"), not an Apple measurement.

`press` was measured frame by frame (60 fps) from Apple's interactive glass example: +8.4% peak and +7.3% settled about 200 ms after the press, back in ~170 ms with a 0.6% undershoot; brightness +7.7%. A lifted control knob (segmented control) grows more: `pressScale` ≈ 1.22.

Physical constants if you implement your own spring: stiffness k = (2π / duration)², damping c = 4π(1 − bounce) / duration (mass 1). Qt's `SpringAnimation {spring, damping}` doesn't map 1:1 — tune presets visually in one place (the `Motion` singleton) and reuse them; never invent per-component values.

A floating surface with no origin (the launcher) materializes instead of fading: scale 0.92 → 1 on `smooth`, the glass's veil from 30% to full (`presence`) with a faint `bloom` at mid-way, and the content only once the glass is ~35% there; closing on `dismiss`, content first. A selection that moves along a row (switcher's lens, the picker's lens over its gliding strip) behaves like the segmented knob: lifted (`held`) while more than ~45% of a step away, landing on `land`; the switcher's lens moves with two edges on two springs like the switch's knob.

Reduce Motion: positions/sizes jump, opacity cross-fades over 0.15 s.

## Icons

- Own monochrome template icons, single color (label/secondaryLabel), 16 pt in the bar, 1.5 pt stroke on a 16 grid, rounded caps/joins to sit next to Inter.
- Open-licensed sets (Lucide ISC, Phosphor MIT) are acceptable as a starting shape only with the license kept; SF Symbols are not usable here.
