// Picks the accent color from a wallpaper's palette. Plain JS so QML can
// import it and node can test it (accent.test.mjs).

function clamp(x, lo, hi) {
    return Math.max(lo, Math.min(hi, x));
}

export function toHsl(c) {
    const max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b);
    const l = (max + min) / 2;
    if (max === min)
        return { h: 0, s: 0, l };
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h;
    if (max === c.r)
        h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0);
    else if (max === c.g)
        h = (c.b - c.r) / d + 2;
    else
        h = (c.r - c.g) / d + 4;
    return { h: h / 6, s, l };
}

export function fromHsl(h, s, l) {
    const k = n => (n + h * 12) % 12;
    const a = s * Math.min(l, 1 - l);
    const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1));
    return { r: f(0), g: f(8), b: f(4) };
}

function luminance(c) {
    const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/** WCAG contrast ratio between two colors. */
export function contrast(a, b) {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/** White labels on the accent must read at least as well as on Apple's blue (3.6:1). */
export const minContrast = 3.5;

/**
 * The wallpaper's dominant hue as a vivid accent, or null when the wallpaper
 * has too little color (then the system blue stays).
 *
 * `colors` is a median-cut palette (Quickshell's ColorQuantizer), so every
 * entry stands for about the same share of the image. Hues are grouped in 30°
 * families and the family with the most saturation wins, so a small vivid
 * detail doesn't beat a large calm area. The result is pushed toward Apple's
 * accents (saturated, mid-light) and darkened until white text reads on it.
 */
export function wallpaperAccent(colors, dark) {
    if (!colors || colors.length === 0)
        return null;
    const families = new Map();
    let chromatic = 0;
    for (const c of colors) {
        const { h, s, l } = toHsl(c);
        if (s < 0.2 || l < 0.08 || l > 0.9)
            continue;
        chromatic++;
        const key = Math.floor(h * 12) % 12;
        const family = families.get(key) || { weight: 0, best: null };
        family.weight += s;
        // A mid-light swatch shows its hue best.
        const score = s * (l > 0.15 && l < 0.65 ? 1 : 0.5);
        if (!family.best || score > family.best.score)
            family.best = { score, h, s };
        families.set(key, family);
    }
    if (chromatic < 0.12 * colors.length)
        return null;
    let win = null;
    for (const family of families.values())
        if (!win || family.weight > win.weight)
            win = family;
    const h = win.best.h;
    const s = clamp(win.best.s, 0.6, 0.9);
    const white = { r: 1, g: 1, b: 1 };
    let l = dark ? 0.58 : 0.5;
    while (l > 0.2 && contrast(fromHsl(h, s, l), white) < minContrast)
        l -= 0.01;
    return fromHsl(h, s, l);
}
