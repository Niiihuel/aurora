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
