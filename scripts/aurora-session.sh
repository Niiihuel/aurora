#!/usr/bin/env bash
# Keep aurora's shell running for the session: start it if it isn't up, and
# start it again if it ever exits. Safe to call more than once — a lock keeps
# a single supervisor per user session.
#
#   scripts/aurora-session.sh [shell-dir]    # default: this repo's shell/
set -u

shell_dir="${1:-$(cd "$(dirname "$0")/../shell" && pwd)}"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/aurora-session.lock"
flock -n 9 || exit 0

# Hyprland tags what it launches with the desktop on screen at that moment,
# and the first window carrying the tag opens there. Everything the shell
# launches would inherit the tag from login, so the first app opened after
# logging in landed on the login's desktop instead of the one on screen.
unset HL_INITIAL_WORKSPACE_TOKEN

# The liquid glass window rims (plugins/rims). The system builds them against
# the Hyprland it runs and says where (AURORA_RIMS_SO); one built for another
# Hyprland refuses to load.
[ -f "${AURORA_RIMS_SO:-}" ] && hyprctl plugin load "$AURORA_RIMS_SO" >/dev/null 2>&1

# The shell, and the lock screen as its own process (so the shell's hot
# reloads never touch a locked session; see shell/lock.qml).
while true; do
    for config in "$shell_dir" "$shell_dir/lock.qml"; do
        # `ipc show` answers only when an instance of this config is alive.
        if ! qs -p "$config" ipc show >/dev/null 2>&1; then
            qs -p "$config" -d 9>&- >/dev/null 2>&1
        fi
    done
    sleep 5
done
