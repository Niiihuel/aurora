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

The material comes from `glass.frag` (limn's optics: convex squircle bezel, refraction eta 1/1.5, 5-tap bend, chromatic dispersion, CSS saturate 2.2, tint veil, iOS 27 one-pixel hairline lit from the top-left plus a faint inner dark line).

| Preset | Tint | Blur radius | Refraction | Dispersion | Use |
|---|---|---|---|---|---|
| regular.dark | `#262628` @ 60% | 8 | 32 (large) / 14 (small) | 0.5 | menus, panels, banners |
| regular.light | `#F5F5F7` @ 55% | 8 | same | 0.5 | light appearance |
| clear | 15–25% | 4 | 32 | 0.6 | over media only (+35% dim on bright backdrops) |
| bar | user slider 0–60% | 8 | 14 | 0.4 | the menu bar itself |
| knob | white @ 12% (dark) / 50% (light) | sharp | 4, bezel 6 | 0 | a control's knob at rest; refracts the control's hidden "selected" copy |
| lens | white @ 16% / 30% | sharp | 10, bezel 7 | 0.8 | a knob while lifted: magnify 1.1, flat middle, bent rim |

`bezel` limits the bending band to a rim (points). Without it a capsule's bezel is its whole height and text under it duplicates into ghost rows. `magnify` zooms the middle of what's refracted.

Shadow under glass (Apple's): `0 10px 40px` black at 20% (dark) / 10% (light). Draw it with `RectangularShadow`, never a layer effect on a resizing item.

Reduce Transparency: replace glass with an opaque `#1C1C1E` (dark) / `#F2F2F7` (light) fill and keep the hairline.

## Radii and spacing

- Spacing scale: 2, 4, 6, 8, 12, 16, 20, 24, 32.
- Menu bar: height 24; item horizontal padding 8; icon size 16; gap between extras 4–8.
- Menus: corner radius 12, inner padding 6, item height 24, item highlight radius 6 (concentric: 12 − 6), separator inset 10.
- Control Center: panel radius 24, padding 12, tiles radius 16 (concentric), tile gap 8.
- Banners (notifications): radius 20, padding 12.
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

`press` was measured frame by frame (60 fps) from Apple's interactive glass example: +8.4% peak and +7.3% settled about 200 ms after the press, back in ~170 ms with a 0.6% undershoot; brightness +7.7%. A lifted control knob (segmented control) grows more: `pressScale` ≈ 1.22.

Physical constants if you implement your own spring: stiffness k = (2π / duration)², damping c = 4π(1 − bounce) / duration (mass 1). Qt's `SpringAnimation {spring, damping}` doesn't map 1:1 — tune presets visually in one place (the `Motion` singleton) and reuse them; never invent per-component values.

Reduce Motion: positions/sizes jump, opacity cross-fades over 0.15 s.

## Icons

- Own monochrome template icons, single color (label/secondaryLabel), 16 pt in the bar, 1.5 pt stroke on a 16 grid, rounded caps/joins to sit next to Inter.
- Open-licensed sets (Lucide ISC, Phosphor MIT) are acceptable as a starting shape only with the license kept; SF Symbols are not usable here.
