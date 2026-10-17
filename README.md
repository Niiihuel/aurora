<p align="center">
  <img src="assets/aurora.png" alt="aurora" width="120">
</p>

<h1 align="center">aurora</h1>

<p align="center">A macOS for Linux, built from scratch: Hyprland, a Quickshell shell and my own liquid glass.</p>

My own NixOS desktop: Hyprland + a Quickshell (QML) shell designed as if Apple had made a macOS for Linux — a full-width menu bar, menus that grow out of their extras, Control Center, and my own liquid glass material. Everything here is written from scratch; nothing is copied from other rices.

## Principles

- Follow Apple's Human Interface Guidelines; use open fonts and my own icons (Apple's fonts and symbols are licensed for Apple platforms only).
- Liquid Glass only on the navigation layer; motion only where it explains a change, always with a Reduce Motion fallback.
- English and Spanish from day one: every string is translated as it's added (`shell/i18n/`), and `nix flake check` fails if one isn't.
- Build one section at a time and verify each (logs, screenshots, frame timing) before moving on.

The design rules, tokens and QML patterns live in the project skill: `.claude/skills/aurora-design/`.

## Roadmap

1. Foundations — flake skeleton, design tokens, motion presets, the glass material
2. Menu bar
3. Menus for the menu bar extras (Wi-Fi, Bluetooth, sound, battery…)
4. Control Center
5. Notifications
6. Launcher (Spotlight-style)
7. OSDs (volume, brightness)
8. Lock screen
9. Window chrome and Hyprland plugins (glass window rims, alt-tab)
10. Hyprland config, login screen and the other apps' colors (independent of Ricelin)

## Layout

- `shell/` — the Quickshell shell (and `shell/lock.qml`, the lock screen as its own process).
- `hypr/` — the Hyprland config (Lua); Home Manager links it into `~/.config/hypr`.
- `plugins/rims/` — the Hyprland plugin that draws the liquid glass window rims.
- `login/` — the SDDM login screen (`nix/login.nix` packages it).
- `nix/` — packages and the Home Manager module; `scripts/` — session, settings and build helpers.
- `assets/` — the aurora logo (the system menu's mark is traced from it).

`~/dotfiles` (the NixOS system) takes this repo as a flake input: it builds the rims plugin and the login screen from what's committed here, and enables `aurora.hyprland` with live links to `hypr/`.
