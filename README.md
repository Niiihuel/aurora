# aurora

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

Until aurora's shell is complete it runs as its own Quickshell config alongside the current desktop (`~/dotfiles`), which stays in use.
