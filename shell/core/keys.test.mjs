// node shell/core/keys.test.mjs — run by `nix flake check` too.
import assert from "node:assert/strict";
import { fromEvent, fromBind, parse, same, caps } from "./keys.mjs";

const SHIFT = 0x02000000, CTRL = 0x04000000, ALT = 0x08000000, META = 0x10000000;

// Letters, with Super (Qt's Meta) and Shift; modifiers in macOS order.
assert.deepEqual(fromEvent(0x51, META, 32), { keys: "SUPER + Q" });
assert.deepEqual(fromEvent(0x51, META | SHIFT, 32), { keys: "SHIFT + SUPER + Q" });
assert.deepEqual(fromEvent(0x51, META | CTRL | ALT, 32), { keys: "CTRL + ALT + SUPER + Q" });
// Shift+1 reports "!": the digit row is read from the keycode.
assert.deepEqual(fromEvent(0x21, META | SHIFT, 10), { keys: "SHIFT + SUPER + 1" });
assert.deepEqual(fromEvent(0x30, META, 19), { keys: "SUPER + 0" });
// Named keys, function keys and Print (the only ones allowed alone).
assert.deepEqual(fromEvent(0x01000004, META, 36), { keys: "SUPER + Return" });
assert.deepEqual(fromEvent(0x20, META, 65), { keys: "SUPER + Space" });
assert.deepEqual(fromEvent(0x01000012, META, 113), { keys: "SUPER + Left" });
assert.deepEqual(fromEvent(0x01000002, ALT | SHIFT, 23), { keys: "ALT + SHIFT + Tab" });
assert.deepEqual(fromEvent(0x01000033, 0, 70), { keys: "F4" });
assert.deepEqual(fromEvent(0x01000009, 0, 107), { keys: "Print" });
// Punctuation only unshifted.
assert.deepEqual(fromEvent(0x60, ALT, 49), { keys: "ALT + grave" });
assert.deepEqual(fromEvent(0x3f, META | SHIFT, 61), { error: "key" });
// A modifier alone waits; Escape cancels; Backspace and Delete clear.
assert.deepEqual(fromEvent(0x01000022, META, 133), { pending: true });
assert.deepEqual(fromEvent(0x01000000, 0, 9), { cancel: true });
assert.deepEqual(fromEvent(0x01000003, 0, 22), { clear: true });
assert.deepEqual(fromEvent(0x01000007, 0, 119), { clear: true });
// With a modifier, Escape and Backspace are shortcuts like any other.
assert.deepEqual(fromEvent(0x01000000, ALT, 9), { keys: "ALT + Escape" });
// A plain letter would stop it being typed.
assert.deepEqual(fromEvent(0x51, 0, 32), { error: "modifier" });

// Reading `hyprctl binds -j` back.
assert.equal(fromBind(65, "Q", 0), "SHIFT + SUPER + Q");
assert.equal(fromBind(8, "", 64), "ALT + code:64");
assert.equal(fromBind(0, "XF86AudioMute", 0), "XF86AudioMute");

// The same keys, however they're written.
assert.ok(same("SUPER + SHIFT + Q", "SHIFT + SUPER + q"));
assert.ok(same("CONTROL + C", "CTRL + C"));
assert.ok(!same("SUPER + Q", "SUPER + SHIFT + Q"));
assert.ok(!same("", "SUPER + Q"));
assert.deepEqual(parse("SUPER + Return"), { mods: 64, key: "return" });

// Keycaps.
const tr = name => `<${name}>`;
assert.deepEqual(caps("SUPER + SHIFT + Q", tr), ["<shift>", "Super", "Q"]);
assert.deepEqual(caps("SUPER + Left", tr), ["Super", "←"]);
assert.deepEqual(caps("SUPER + Space", tr), ["Super", "<space>"]);
assert.deepEqual(caps("SUPER + mouse:272", tr), ["Super", "<mouse272>"]);
assert.deepEqual(caps("ALT + code:64", tr), ["Alt", "<code64>"]);
assert.deepEqual(caps("XF86AudioRaiseVolume", tr), ["<xf86audioraisevolume>"]);
assert.deepEqual(caps("ALT + grave", tr), ["Alt", "`"]);

console.log("keys ok");
