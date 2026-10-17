# aurora

Nihuel's own NixOS desktop (Hyprland + Quickshell shell, macOS-style with liquid glass). The user writes in Spanish (Argentina); reply in Spanish.

- Load the `aurora-design` skill before designing or changing anything in the shell, the Hyprland config or the plugins.
- Own code only: nothing copied from Gakuseei/Ricelin (the desktop aurora replaced). aurora is the running desktop now; `~/dotfiles` is the NixOS system, which takes aurora as a flake input (it builds the rims plugin and the login theme from what's committed here) — keep both working.
- Work one roadmap section at a time (see README) and get the user's sign-off with screenshots before the next.
- Every visible string goes through `I18n.tr("key")` and is added to **both** `shell/i18n/en.json` and `shell/i18n/es.json` in the same change (see the skill's `references/i18n.md`). Run `python3 scripts/check-i18n.py shell` before calling work done.
- Commit only when the user asks.
