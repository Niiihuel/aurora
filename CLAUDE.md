# aurora

Nihuel's own NixOS desktop (Hyprland + Quickshell shell, macOS-style with liquid glass). The user writes in Spanish (Argentina); reply in Spanish.

- Load the `aurora-design` skill before designing or changing anything in the shell, the Hyprland config or the plugins.
- Own code only: don't copy from the Ricelin-derived `~/dotfiles` (that is the desktop currently running, keep it working). The user's own glass shader/backdrop and Hyprland plugins may be rewritten here cleanly.
- Work one roadmap section at a time (see README) and get the user's sign-off with screenshots before the next.
- Every visible string goes through `I18n.tr("key")` and is added to **both** `shell/i18n/en.json` and `shell/i18n/es.json` in the same change (see the skill's `references/i18n.md`). Run `python3 scripts/check-i18n.py shell` before calling work done.
- Commit only when the user asks.
