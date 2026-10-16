// node shell/core/accent.test.mjs — run by `nix flake check` too.
import assert from "node:assert/strict";
import { wallpaperAccent, toHsl, fromHsl, contrast, minContrast } from "./accent.mjs";

const rgb = hex => ({ r: parseInt(hex.slice(1, 3), 16) / 255, g: parseInt(hex.slice(3, 5), 16) / 255, b: parseInt(hex.slice(5, 7), 16) / 255 });
const fill = (hex, n) => Array.from({ length: n }, () => rgb(hex));
const white = { r: 1, g: 1, b: 1 };
const hueOf = c => toHsl(c).h * 360;

// HSL round trip.
for (const hex of ["#0a84ff", "#ff453a", "#30d158", "#7f3fbf"]) {
    const c = rgb(hex), { h, s, l } = toHsl(c), back = fromHsl(h, s, l);
    for (const k of ["r", "g", "b"])
        assert.ok(Math.abs(back[k] - c[k]) < 1e-9, `round trip ${hex}`);
}

// Nothing to go on, or a grey wallpaper: keep the system blue.
assert.equal(wallpaperAccent([], true), null);
assert.equal(wallpaperAccent(fill("#808080", 20).concat(fill("#202020", 12)), true), null);

// A large calm blue area beats a small vivid red detail.
const blue = wallpaperAccent(fill("#2f5f9f", 26).concat(fill("#ff0000", 4), fill("#111111", 2)), true);
assert.ok(hueOf(blue) > 200 && hueOf(blue) < 230, `blue hue, got ${hueOf(blue)}`);

// Every result keeps white labels readable, light and dark, even for yellow.
for (const hex of ["#d9b400", "#c0392b", "#2f5f9f", "#3fa34d", "#8e44ad", "#00b5c0"])
    for (const dark of [true, false]) {
        const a = wallpaperAccent(fill(hex, 32), dark);
        assert.ok(contrast(a, white) >= minContrast, `${hex} dark=${dark}: ${contrast(a, white).toFixed(2)}`);
    }

console.log("accent ok");
