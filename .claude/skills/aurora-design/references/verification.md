# Verifying aurora work

Show, don't claim: every UI change ends with a clean log, screenshots of its states and, for anything animated, frame timing.

## Log

    quickshell log -c <config> | tail                 # want "Configuration Loaded", no errors
    quickshell log -c <config> | grep -iE 'error|warn' # new warnings are bugs until explained

Known benign noise: DBus portal "Could not register app ID", NetworkManager "Object does not exist" for vanished devices.

## Screenshots

- `grim -g "X,Y WxH" out.png` takes logical coordinates; output is physical (2× on the laptop). Zoom small details with `nix shell nixpkgs#imagemagick -c magick out.png -scale 300% zoom.png`, then read the PNG.
- Pointer-driven states (hover, tooltips, clicks) need **real input events**. With the Lua config `hyprctl dispatch movecursor` does nothing at all; warp with `hyprctl eval 'hl.dispatch(hl.dsp.cursor.move({ x = 1108, y = 12 }))'` (logical px), then nudge with `printf 'mousemove 1 0\nmousemove -1 0\n' | dotool` so the surface under the cursor gets pointer focus (a warp alone doesn't move it, and the first click goes to the old surface).
- Read state instead of guessing from screenshots: `qs ipc -p shell call aurora activeMenu` prints the open menu id. Add a temporary `console.log("PROBE …")` and grep `quickshell log -p shell` when you need to see which handler fired; remove the probes after.
- Lint/LSP: the devShell has `qmllint`/`qmlls`, but **don't create `shell/.qmlls.ini`**: the shell and the lock (`shell/lock.qml`) are two Quickshell instances in the same folder, each rewrites that file with its own paths and wakes the other — a loop that pinned both at 100% CPU and made video stutter. The runtime log stays the real check.
- The user is often using the mouse while you test: synthetic pointer input then lands in the wrong place (and disturbs them). Prefer driving states from code (`held`, timers in the gallery, IPC) and keep pointer automation for when it's truly needed. Each `dotool` invocation creates a new virtual device whose first events can be dropped; send a whole sequence through one invocation with pauses in between.
- `shell/gallery.qml` (run `quickshell -p shell/gallery.qml`) shows the foundations — type, colors, glass presets, springs, a self-pressing glass and a segmented knob — for screenshot checks.
- Surfaces with IPC can be opened directly (`qs -c <config> ipc show` lists them).
- Morphs: capture mid-animation too (`sleep 0.09` after triggering) — clipping and early-content bugs only show there.
- A notification or toast may cover the area; wait for it to expire before capturing.

## Frame timing

Restart the shell with Qt's render-loop timing, drive the animation, then read per-frame gaps:

    pkill -f '^/nix/store/[^ ]*quickshell -c <config> -d$'   # anchor the pattern, or pkill kills your own shell
    QT_LOGGING_RULES="qt.scenegraph.time.renderloop=true" setsid -f quickshell -c <config> -d
    quickshell log -c <config> --log-times | grep 'elapsed since last call'

Group by second and window; count gaps > 12 ms and > 20 ms. Healthy: ~1 frame/s idle, steady 120 fps with no gaps > 20 ms while animating. If a watchdog relaunches the shell, it may beat you to it — check the process environment for `QT_LOGGING_RULES`.

## Comparing an animation with Apple's, frame by frame

1. Get Apple's footage: WWDC session pages list the HD mp4 (`curl -s https://developer.apple.com/videos/play/wwdc2025/<id>/ | grep -oE 'https://devstreaming-cdn[^"]+_hd.mp4'`); the page transcript (`data-start` timestamps) tells you where the moment is. "Meet Liquid Glass" (219) at ~305 s shows a menu popping out of a toolbar button.
2. Record aurora at 60 fps without privileges: `nix shell nixpkgs#wf-recorder -c wf-recorder -g "X,Y WxH" -r 60 -f out.mp4` (gpu-screen-recorder needs root caps here). Trigger the animation through IPC so no pointer is involved; stop with `pkill -INT`.
3. Find the first frame that changes, then lay both out at the same 33 ms steps: `ffmpeg … -vf "select='gte(n,START)*not(mod(n-START,2))',crop=…,scale=170:-1,tile=19x1" -fps_mode vfr` for aurora and `-ss <t> -t 0.62 … tile=19x1` for Apple, stacked with `magick … -append`.
4. Measure, don't eyeball: threshold the frames (pure white = bloom, glass vs background) and print sizes per frame; note when the camera zooms (the shape's top moves) and stop measuring there.

The menu pop (bar/MenuLayer.qml, Motion.menuDrop/menuOpen/menuPhases) was fitted this way on 2026-10-16. The close (Motion.menuClose/menuMerge/menuCloseHold) too: Apple's close is at ~317.2 s in session 219 (menu shrinks evenly into a drop by ~170 ms, content gone by ~100 ms, the drop melts into the button as a bump until ~300 ms). When the shapes differ (Apple's menu is tall, ours wide), compare fractions of the way to the target, and check the curve by simulating the spring in a few lines of Python instead of eyeballing tiny frames.

## Nix

- Validate by building, not evaluating: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link`. `git add` new files first (flakes only see tracked files).
- Before a switch, compare with the running system: `nix store diff-closures /run/current-system <new-toplevel>` and tell the user exactly what changes.
- The user runs `sudo nixos-rebuild switch` themselves (sudo needs their password).

## Hyprland plugins

- A plugin must be built against the exact running Hyprland commit (ABI hash gate). Loading a crashing plugin kills the session — never `hyprctl plugin load` without the user's go-ahead, and tell them to save their work first.
- Hyprland's plugin API changes a lot between releases; check the target commit's headers before porting.
