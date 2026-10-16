# Quickshell/QML patterns for aurora

Lessons from building the previous shell's glass, tooltips and morphing surfaces. Each one cost a debugging session; read before editing QML.

## Contents
1. Hot reload is live editing
2. Liquid glass: how it works
3. Morphing surfaces
4. Shadows and layers
5. Performance
6. Small traps

## 1. Hot reload is live editing

The shell's config directory is symlinked into `~/.config/quickshell/<name>`, and Quickshell reloads on every save. A save that leaves the QML broken (an `id` referenced before it exists, a property alias to a property not yet declared, a shader uniform with no matching property) makes it error-reload; repeated error reloads can freeze the compositor (the user recovers by closing/opening the lid).

- Make every individual save self-consistent. When two files depend on each other, write the provider first (new property/component with a safe default), then the consumer.
- For changes that span several spots in one file, apply them in a single write (a small Python replace with asserted counts works well) rather than several separate edits.
- New shader uniforms: add the QML properties first, recompile the `.qsb` second (missing uniforms default to zero, which can make a glass shape collapse for a frame but won't crash).
- After each save: `quickshell log -c <config> | tail` → want `Configuration Loaded`, no `error`, `is not a type`, `does not exist`.

## 2. Liquid glass: how it works

- A Wayland client cannot read what's beneath its surface. `GlassBackdrop` rebuilds the scene itself: the current wallpaper (cropped like the wallpaper daemon does) plus a live `ScreencopyView` of each window under the glass `region`, positioned from `Hyprland.toplevels[].lastIpcObject` (`at`, `size`, `floating`, `focusHistoryID`, `workspace`, `monitor`; refresh with `Hyprland.refreshToplevels()` on rawEvents; `.wayland` is the capturable Toplevel). The scene is downsampled to ¼ and blurred with a separable Gaussian, then sampled by `glass.frag`.
- Textures can't cross windows: each layer-shell window needs its own `GlassBackdrop`.
- `GlassSurface` maps itself onto the backdrop with `mapToItem(window)`, which isn't reactive — pass the geometry it depends on through its `track` property.
- The `region` must be exactly the glass footprint (plus any tooltip area below it). A margin around it made a resting bar overlap the top window, which kept a screencopy streaming and forced the whole full-screen overlay to redraw at 120 fps forever.
- Content that the glass should refract from inside the same window (e.g. a segmented control's labels under a lifted glass knob) can be captured with a `ShaderEffectSource` of that content — no screencopy needed.
- Interactive glass: `interactive` (pointer) or `held` (code/keyboard) lifts it: scale on `Motion.press`, highlight around the press point, material blending toward `liftedMaterial`, and a shadow that grows with the lift.
- A control knob that lenses its control (Apple's segmented control): render a hidden copy of the control in its *selected* style (solid track + full-weight labels) and point the knob's Glass at it with `refracts` + `hideRefracted: true`. At rest (`Tokens.glass.knob`) the knob shows that copy as a solid pill with its label; while moving (`held` while the position spring is unsettled) it lifts into `Tokens.glass.lens`. Don't draw a separate label on top of the knob — it switches before the knob arrives and doubles the text.
- A lifted knob bigger than its control (the switch's lens is ~1.7x and overflows the track): give the hidden copy a clear margin (`anchors.margins: -12` on the copy, `+12` on its content). A `refracts` capture past the item's bounds repeats its border pixels, so without the margin the lens shows track all the way out instead of the track's edges. Glass with `refracts` needs no backdrop. A lifted lens is lifted only while it travels: drop it on arrival (`Math.abs(to - value) > 0.12`), not when the spring finally settles, or it hangs there for ~0.4 s.
- **Shader changes need a restart, QML changes don't.** Qt caches a loaded `.qsb` by its URL for the life of the process, so a recompiled shader is ignored by hot reload. After `scripts/shaders.sh`, restart the shell (`pkill` the `quickshell -p …/aurora/shell -d` process; `aurora-session.sh` brings it back within 5 s).
- Glass that runs edge to edge (the menu bar) sets `edge: false`: no bent rim, no dispersion, no hairline. macOS draws its bar flat; the lit edge only belongs on floating shapes.
- Compile shaders with the `qsb` from the same Qt version Quickshell links (`nix-store -qR $(readlink -f $(command -v quickshell)) | grep qtbase` → use that version's `qtshadertools`): `qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o x.frag.qsb x.frag`.

### Keeping glass live (learned the hard way, Control Center)

- **The rim must refract the sharp scene.** `GlassBackdrop` gives a blurred texture (`texture`, the frost) and a sharp one (`sharpTexture`); the shader moves from the first to the second toward the rim. Bending only a blur is invisible and the glass reads as a flat frosted panel.
- **No glass inside a `layer.enabled` item at rest.** A layer is a snapshot that doesn't hear its glass children's backdrop changing: the glass freezes on whatever was behind when it was created. `MenuLayer` enables its content layer only while the content blurs in/out (`reveal < 0.999`).
- **Glass re-maps itself only when `track` changes** (mapToItem isn't reactive). Anything that moves an ancestor — a panel sliding to its final place after it learns its width — must reach the glass's `track`, or it samples the wrong spot of the screen (looks static and the wrong color). `MenuLayer` binds `panelRect` into the panel's `track`; Control Center modules add `panel.track` to theirs.
- **Pressed glass grows** (`Motion.pressScale`): never clip it at the panel's edge at rest. `MenuLayer` clips its content only while the glass morphs.
- Verify over a playing video: two screenshots a second apart must differ under the glass.

## 3. Morphing surfaces

A surface that grows out of the bar (menu, panel) is laid out at its full size while its container animates.

- Clip it to the animating container (`clip: true` on the surface root, or on a content column whose height is bound to the container). Without it the content shows before the open morph finishes and sticks out while it shrinks on close.
- Fade content in only near the end of the morph (opacity from progress ≳ 0.55) and out quickly at the start of the close.
- Surfaces that are re-created while already open (hot reload) don't get `onActiveChanged`; run their initialization in `Component.onCompleted` too.
- Keep one registry of surfaces (names, sizes, back-navigation) instead of repeating the list in several hardcoded places; the old shell needed four lists kept in sync and broke when one was missed.

## 4. Shadows and layers

- Never put `layer.enabled` + `MultiEffect` on an item whose size animates: the offscreen texture is re-allocated and re-blurred every frame (measured frame gaps up to 25 ms on the morph). Use `RectangularShadow` (QtQuick.Effects, Qt ≥ 6.9): analytic, no texture.
- Layers are fine on fixed-size items (an icon, a tooltip at its final size).

## 5. Performance

- A threaded render loop keeps rendering at the full refresh rate while any animation runs or anything marks the scene dirty — including animations on invisible items and live screencopies. Gate every `running:` on visibility, stop captures when not needed.
- Target: ~1 frame/s at idle (clock tick), 120 fps with no gaps > 20 ms during morphs. Measure it (see `verification.md`), don't guess.
- Never `live: true` on a ScreencopyView that this shell itself shows: Hyprland answers the capture on its next repaint, our redraw causes that repaint, and the pair loops at the display's full rate even when nothing changes (measured: a menu at rest over a terminal, 120 fps and ~15% CPU). `GlassBackdrop` re-captures on a 30 fps timer instead, which doesn't show under the blur.
- Measure with `QT_LOGGING_RULES="qt.scenegraph.time.renderloop=true"` (restart the shell with it: `pkill` the instance, start `qs -p shell -d` with the env before the supervisor does), count `frame rendered` lines per state in `quickshell log -p shell`, and read per-thread CPU from `/proc/<pid>/task/*/stat`. In `syncAndRender`, `swap` is vsync wait, not cost.
- Canvas items repaint on the CPU; keep them small and avoid repainting them every frame for idle effects.

## 6. Small traps

- `pragma ComponentBehavior: Bound`: access child ids bare (`cursorFile.text()`), never as `root.cursorFile`.
- **QML ids shadow properties.** Inside an element, `backdrop: backdrop` assigns the element's own (null) property, and a Column with `id: text` makes a child Text's `text.length` mean the Column. Give ids distinct names (`bannerBackdrop`, `textColumn`).
- Notifications: only one process can own org.freedesktop.Notifications; a NotificationServer created even for a moment keeps retrying and grabs the name when the owner restarts. Quickshell re-delivers kept notifications after a hot reload with `lastGeneration` set — don't banner those again.
- Icons: `Quickshell.iconPath(name, true)` (checked) is the reliable lookup; a long-running process once kept negative results (Discord/Cursor "missing" until restart). App icons that are absolute paths need `file://`; a missing themed icon "loads" as an empty image, so check the checked form instead of `Image.status`.
- **Lock screen** (`shell/lock.qml`, its own process): never test it by really locking — use the `preview` IPC (same screen in an overlay, real PAM, no lock). It writes `$XDG_RUNTIME_DIR/aurora-locked` while locked and relocks on start if the marker exists; Hyprland needs `misc.allow_session_lock_restore = true` for that. Glass masked to a shape (the clock's numerals): put the mask on the Glass's own `layer.effect` — a separate MultiEffect with an invisible source rendered nothing.
- **Keys through Hyprland global shortcuts** (`GlobalShortcut` + `hl.dsp.global("aurora:x")`): no keyboard grab needed. A bind with `release = true` sends the global as a *release* — handle `onReleased`. Releasing a modifier only matches by keycode (`"ALT + code:64"`, not `"ALT + Alt_L"`), and it must be `non_consuming` or apps lose that modifier.
- Hyprland's Lua config rejects `hyprctl keyword`; use `hyprctl eval '<lua>'`. Mirrored outputs only show in `hyprctl monitors all`.
- **Layer shells and Hyprland input** (read from Hyprland's source, `LayerSurface.cpp`/`InputManager.cpp`):
  - While any layer is `WlrKeyboardFocus.Exclusive`, Hyprland sends *every* pointer event to exclusive layers. Exclusive is right for modal dialogs, wrong for a menu: the bar under it never hears a click or hover.
  - A layer mapping (or turning Exclusive) with keyboard interactivity grabs the **pointer** focus too, wherever the cursor is, until the pointer moves. A second click in place lands on the new layer, not on what's under the cursor.
  - Exclusive → OnDemand while focused keeps the keyboard and makes Hyprland re-pick the pointer target. `bar/MenuLayer.qml` uses that: Exclusive for 60 ms on open, then OnDemand.
  - An input mask meant to let clicks through part of a layer didn't reach the compositor; size the layer to leave that area out instead (the menu layer starts below the bar).
- Settings sliders that rewrite Hyprland config must debounce `hyprctl reload` through a `Timer` (one reload per drag, not per step) — a reload storm froze the compositor once.
- Notifications: drop the `default` action from the button row (a click on the banner already runs it) and actions with blank labels (some clients send them; they render as empty pills). Play the arrival sound via `pw-play`, honoring `suppress-sound`, `sound-file`/`sound-name` and Do Not Disturb.
- Every menu or popover opens with `GlassMorph` (a drop out of the control that swells into the panel and melts back): `PopupMenu` for item lists, or custom content inside a `GlassMorph` that works in the window's coordinates (`fromRect` = the button, `toRect` = the panel; see annotate/AnnotateToolbar's `Pop`). The content has no Glass of its own. Never a popover that just toggles `visible`.
- Idle cost rules (from the 2026-10-16 audit): a hidden glass window must do nothing — GlassBackdrop already stops listing, capturing and listening while its window is hidden, and a backdrop whose glass isn't showing (a closed menu, a countdown not running) gets `captureWindows: false`; a bar slid away over a full-screen window must not keep capturing it (`captureWindows: shown`, content `visible: false` when fully away); flat glass (`edge: false`) doesn't bind the sharp texture.
- Repeaters over JS arrays that get reassigned (notifications, networks, devices) use `ScriptModel { values: … }`: it diffs by object, so existing delegates aren't destroyed and re-animated. A per-item binding that changes during a drag must only touch that item (compute it in the delegate, not by rebuilding the model).
- No polling where an event exists: services expose an IPC hook (`wallpaperChanged`) for scripts to call; a fallback poll is long (minutes) and skips the assignment when nothing changed. Timers that feed a view (media position) run only while that view exists (a watcher count).
- Heavy overlays used now and then (the screenshot editor) live in a `LazyLoader` with `active:` tied to their state.
