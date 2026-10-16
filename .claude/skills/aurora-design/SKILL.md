---
name: aurora-design
description: Design and build rules for aurora, Nihuel's own NixOS desktop with a Quickshell/QML shell styled like macOS with Liquid Glass. Use this whenever you design, build, review or fix any part of the aurora shell — the menu bar, menu bar extras and their menus, Control Center, notifications, Spotlight-style launcher, OSDs, lock screen, window chrome, Hyprland config or plugins — and whenever the user asks for something "like Apple / macOS / iOS", talks about liquid glass, animations that feel off, spacing, typography or icons in aurora, even if they don't name this skill.
---

# aurora design

aurora is the user's own desktop: NixOS flake + Hyprland (Lua config) + a Quickshell (QML) shell. The goal is a desktop that looks and behaves as if Apple had designed a macOS for Linux, built entirely from the user's own code. Think like an Apple designer: every element earns its place, motion explains what happened, the glass serves navigation and never decorates content.

## Ground rules

- **Own code only.** aurora replaces a desktop that was ported from Gakuseei/Ricelin. Do not copy or adapt Ricelin-derived code (the old `~/dotfiles/configs/quickshell/pill/*`, its Lua config, scripts). The user's own pieces from that era may be rewritten cleanly here: the liquid glass shader and its backdrop (originally ported from the user's Rust UI library limn, `~/projects/personal/lienzo`), the alt-tab and glass-border Hyprland plugins. Study other projects only for the pattern; write original code.
- **Apple's rules, not Apple's assets.** SF Pro, SF Symbols and Apple's wallpapers are licensed for Apple platforms only. Use Inter (or another open face) and the project's own monochrome icons. See `references/tokens.md`.
- **Every string in English and Spanish.** No visible text is a literal: it goes through `I18n.tr("key")` and the key is added to every file in `shell/i18n/` in the same change, with a real translation that follows each language's Apple conventions. `scripts/check-i18n.py` / `nix flake check` enforce it. See `references/i18n.md`.
- **One section at a time.** The shell is built section by section (foundations → menu bar → extras' menus → Control Center → notifications → launcher → OSD → lock → window chrome). Finish, verify and get the user's sign-off on one before starting the next.
- **Liquid glass is the standard, everywhere.** Every floating control and surface (menus, panels, Control Center modules, toggles on *and* off, knobs, dialogs, banners) is live liquid glass from `components/Glass`: it refracts what's really behind it, live, bent at a lit rim. Never substitute a flat or opaque fill, a frosted rectangle, or a static snapshot; "on" states are bright glass (`Tokens.glass.toggleOn`), not white paint. Check it over moving content (a playing video) before calling it done. The rules that keep it live are in `references/qml-patterns.md` §2.
- **Never break the running desktop.** aurora's shell runs as its own Quickshell config next to the old shell until it replaces it. Quickshell hot-reloads every save into the live session, and a broken save can wedge the compositor — see `references/qml-patterns.md` before editing QML.

## How to decide what to build

Before writing a component, answer these from `references/hig-macos.md`:

1. What would macOS do here? Find the closest system component (menu bar extra, menu, Control Center module, banner, HUD, Spotlight) and follow its anatomy and behavior. A menu bar extra opens a **menu**; only rich, multi-control surfaces get a panel (that's Control Center's job).
2. Which layer is it on? Navigation/controls float on **Liquid Glass**; content (lists inside a panel, text, media) sits on plain material. Glass on glass is avoided.
3. Regular or clear glass? Regular for anything with text (menus, panels, banners). Clear only over rich media, with a 35% dim when the backdrop is bright.
4. Does it need motion? Motion must explain a change (where something came from, where it went). Frequent interactions (hover over icons, typing) get little or none. Every animation has a Reduce Motion fallback.

## Building blocks

Shared components live in the shell's `components/` and singletons; reuse them instead of re-deriving values:

- `Glass` + `GlassBackdrop` + `shaders/glass.frag` — the liquid glass material. The backdrop is per window; it composes the wallpaper plus live screencopies of windows under the glass region. See `references/qml-patterns.md` for how it works and its pitfalls.
- `Tokens` (spacing, radii, type scale, colors) and `Motion` (spring presets, durations, Reduce Motion) singletons — values in `references/tokens.md`. Never hard-code a size, color or duration that a token covers; if a token is missing, add it to the singleton first.

## Workflow per section

1. Re-read the relevant HIG notes and look at what macOS does (screenshots, Apple docs via `references/hig-macos.md` → "Getting Apple docs").
2. Write a short plan for the user: anatomy, states, interactions, motion, which tokens. Agree before coding when the section is new.
3. Build with atomic, self-consistent saves (hot reload).
4. Verify per `references/verification.md`: clean log, a screenshot of each state (and mid-animation frames for morphs), frame timing for anything animated.
5. Show the user the screenshots and ask for sign-off.

## Reference files

- `references/hig-macos.md` — distilled Apple HIG for this project: menu bar, extras, menus, Control Center, Liquid Glass, materials, motion, typography, color, and how to fetch more Apple docs/videos.
- `references/tokens.md` — the concrete design tokens (type scale, colors, radii, spacing, glass presets, springs) and licensing notes.
- `references/qml-patterns.md` — Quickshell/QML patterns and traps learned the hard way: hot reload, morphing surfaces, glass backdrop, shadows, performance.
- `references/i18n.md` — the language system: keys, plurals, variables, locale, rules for new strings, adding a language.
- `references/verification.md` — how to check work: logs, screenshots with real pointer input, frame timing, Nix builds.
