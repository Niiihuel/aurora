# Apple HIG, distilled for aurora

Source: Apple Human Interface Guidelines (the-menu-bar, materials, motion, typography, color, layout) and the Liquid Glass adoption guide, read October 2026 (macOS 26 "Tahoe" / 27). Quotes are paraphrased; go back to the source when a decision hinges on the exact wording.

## Contents
1. Menu bar
2. Menu bar extras and menus
3. Control Center
4. Liquid Glass and materials
5. Motion
6. Typography
7. Color
8. Translating to Linux/Hyprland
9. Getting Apple docs and videos

## 1. Menu bar

- Spans the full width of the screen's top edge. **Height: 24 pt** (in Hyprland logical px = pt).
- Leading side: the system menu (Apple menu equivalent — about, settings, sleep/restart/shut down, lock, log out), then the frontmost app's name **in bold**, then its menus. Trailing side: menu bar extras, then Control Center, then the clock.
- Menu titles are short, ideally one word, title case.
- When space runs out the system tightens spacing and truncates; extras hide before app menus.
- In full-screen the menu bar hides and reveals when the pointer reaches the top edge.
- macOS 26 made the bar fully transparent over the wallpaper (glass shows when menus open); macOS 27 added a transparency slider. Offer the user that slider.

## 2. Menu bar extras and menus

- An extra is a monochrome **template icon**: shape only, the system tints it for light/dark backgrounds and the selected state. No colored icons in the bar.
- Clicking an extra opens a **menu**, not a popover, unless the content is too complex for a menu (that's why Wi-Fi/Bluetooth/Sound in macOS are rich menus with toggles and lists, and Control Center is a panel).
- Menus: rounded glass (regular variant), items 22–24 pt tall, 13 pt text, section separators, keyboard shortcut column on the trailing side, disabled items stay visible (dimmed) rather than hidden.
- The selected item gets the accent-colored highlight capsule inset from the menu edges.
- Let the user choose which extras appear; never depend on an extra being present.

## 3. Control Center

- A panel of modules (connectivity group, Do Not Disturb/Focus, display brightness, sound, now playing), each a rounded glass tile; tiles expand in place to show detail (e.g. the Wi-Fi network list) with a matched-geometry morph.
- Modules are user-configurable.

## 4. Liquid Glass and materials

- Liquid Glass is the **functional layer** for controls and navigation that float above content. Never use it in the content layer (exception: a slider/toggle knob turns into glass while being dragged).
- Use it sparingly: overused glass distracts from content.
- **Regular** variant: blurs and adjusts luminosity for legibility. Use for anything with text: menus, panels, banners, alerts, popovers, sidebars.
- **Clear** variant: highly translucent, only over visually rich media (photos, video). If the backdrop is bright, add a 35% dark dimming layer.
- Glass has no inherent color; it takes on the surroundings. Apply color sparingly (a tint suggests prominence, e.g. the primary action).
- Shapes are concentric with their container and the hardware: nested radii = outer radius − inset.
- Interactive glass reacts to touch/pointer: it lifts (scales up ~1.15–1.3, goes clearer, magnifies what's under it, deepens its shadow) and settles back on release with a little spring overshoot.
- Glass doesn't fade in: it **materializes** (WWDC25 "Meet Liquid Glass"). A menu pops out of what was clicked as a small **clear, lensing** drop (~60 ms), stretches into the menu's shape with a small overshoot, gains its veil as it forms while the content focuses in from a blur (~230–400 ms) and settles by ~450 ms. Closing shrinks the menu evenly into a dense drop (content blurred out by ~100 ms, drop by ~170 ms) that melts into the item as a flattening bump by ~300 ms. It is never white: in Apple's demo footage the drop *looks* white only because it's pressed glass over a light grey background — don't copy that into a dark theme. Implemented in `bar/MenuLayer.qml` with the timings in `Motion.menuPhases`.
- Glass shapes inside one container blend into each other when close (a liquid "neck") and morph into one another on transitions (matched geometry); unrelated ones fade/materialize instead.
- Behind the content layer, use standard materials (plain blur + vibrancy), not glass.
- Respect Reduce Transparency: fall back to an opaque fill.

## 5. Motion

- Add motion purposefully; it supports the experience, never overshadows it.
- Make it optional: honor Reduce Motion (replace movement with fades or nothing).
- Feedback motion is brief and precise, follows the pointer/gesture, and can be interrupted — never make people wait for an animation to finish.
- Avoid motion on interactions that happen very often (hovering icons in the bar, typing).
- Apple's springs are critically or slightly under-damped: smooth (no bounce) for most UI, snappy (small bounce) for direct manipulation, bouncy only for playful moments.

## 6. Typography (macOS built-in text styles)

| Style | Weight | Size/Line (pt) | Emphasized |
|---|---|---|---|
| Large Title | Regular | 26/32 | Bold |
| Title 1 | Regular | 22/26 | Bold |
| Title 2 | Regular | 17/22 | Bold |
| Title 3 | Regular | 15/20 | Semibold |
| Headline | Bold | 13/16 | Heavy |
| Body | Regular | 13/16 | Semibold |
| Callout | Regular | 12/15 | Semibold |
| Subheadline | Regular | 11/14 | Semibold |
| Footnote | Regular | 10/13 | Semibold |
| Caption 1 | Regular | 10/13 | Medium |
| Caption 2 | Medium | 10/13 | Semibold |

The menu bar and menus use the 13 pt body size; the app name in the menu bar is bold. macOS has no Dynamic Type.

## 7. Color

- Use semantic colors (label, secondary/tertiary/quaternary label, separator, control accent) instead of raw hex, so light/dark/increased-contrast all work.
- Don't rely on color alone to convey state; pair it with shape or text.
- The accent color is the user's choice (System Settings) — make it a setting.

## 8. Translating to Linux/Hyprland

- No global app menus on Wayland: most apps don't export them. The leading side shows the system menu, the frontmost app's name (bold) and, optionally, workspaces. Don't fake per-app menus.
- Window chrome (title bars/traffic lights) belongs to the apps; aurora styles window borders/rims via the compositor (Hyprland decoration settings or the glass-border plugin), not by drawing over windows from QML.
- A layer-shell overlay is above every window: anything drawn per-window from QML ignores stacking order and lags behind compositor animations. Prefer compositor plugins for per-window effects.

## 9. Getting Apple docs and videos

developer.apple.com pages are a JavaScript app; fetch the data instead:

- HIG page JSON: `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json` (e.g. `the-menu-bar`, `materials`, `motion`, `menus`, `popovers`, `toggles`, `sliders`).
- Other docs: `https://developer.apple.com/tutorials/data/documentation/<path>.json`.
- Walk `primaryContentSections` for text; media URLs are in `references[*].variants[].url` — prefix videos with `https://developer.apple.com/tutorials`.
- ffmpeg isn't installed system-wide: `nix shell nixpkgs#ffmpeg -c ffmpeg -i in.mp4 -vf "fps=2,scale=540:-1,tile=2x8" -frames:v 1 sheet.png` makes a contact sheet to study an animation.
