// Keyboard shortcuts as Hyprland writes them ("SUPER + SHIFT + Q"): reading
// a key press into one, reading `hyprctl binds -j` back, comparing two, and
// the keycaps Settings shows. Pure functions, so they're tested with node
// (keys.test.mjs); Qt's key and modifier codes are spelled out here.

const Mod = { SHIFT: 1, CTRL: 4, ALT: 8, SUPER: 64 };
/** Display and writing order, as macOS orders its modifiers. */
const ORDER = ["CTRL", "ALT", "SHIFT", "SUPER"];

const QtMod = { shift: 0x02000000, ctrl: 0x04000000, alt: 0x08000000, meta: 0x10000000 };

const Qt = {
    escape: 0x01000000, tab: 0x01000001, backtab: 0x01000002, backspace: 0x01000003,
    enter: 0x01000004, keypadEnter: 0x01000005, insert: 0x01000006, delete: 0x01000007,
    print: 0x01000009, home: 0x01000010, end: 0x01000011,
    left: 0x01000012, up: 0x01000013, right: 0x01000014, down: 0x01000015,
    pageUp: 0x01000016, pageDown: 0x01000017,
    f1: 0x01000030, f24: 0x01000047,
    space: 0x20,
};
/** Modifier keys on their own: keep waiting for the real key. */
const MODIFIER_KEYS = new Set([0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01001103, 0x01000053, 0x01000054, 0x01000055]);

const NAMED = new Map([
    [Qt.tab, "Tab"], [Qt.backtab, "Tab"], [Qt.enter, "Return"], [Qt.keypadEnter, "Return"],
    [Qt.insert, "Insert"], [Qt.delete, "Delete"], [Qt.backspace, "BackSpace"], [Qt.print, "Print"],
    [Qt.home, "Home"], [Qt.end, "End"], [Qt.left, "Left"], [Qt.up, "Up"], [Qt.right, "Right"],
    [Qt.down, "Down"], [Qt.pageUp, "Page_Up"], [Qt.pageDown, "Page_Down"], [Qt.space, "Space"],
    [Qt.escape, "Escape"],
]);
// Punctuation by keysym, only unshifted (with Shift, Qt reports the shifted
// symbol, which depends on the layout).
const PUNCTUATION = new Map([
    [0x2c, "comma"], [0x2d, "minus"], [0x2e, "period"], [0x2f, "slash"], [0x3b, "semicolon"],
    [0x3d, "equal"], [0x5b, "bracketleft"], [0x5c, "backslash"], [0x5d, "bracketright"],
    [0x60, "grave"], [0x27, "apostrophe"],
]);

/**
 * A key press while recording a shortcut, as { keys } ready to bind, or
 * { pending } (a modifier alone), { cancel } (Escape), { clear } (Backspace
 * or Delete: turn the shortcut off), or { error: "modifier" | "key" }.
 * `scanCode` is the X keycode (evdev + 8), which places the digit row even
 * when Shift turns 1 into "!".
 */
export function fromEvent(key, modifiers, scanCode) {
    if (MODIFIER_KEYS.has(key))
        return { pending: true };
    const mods = [];
    if (modifiers & QtMod.ctrl) mods.push("CTRL");
    if (modifiers & QtMod.alt) mods.push("ALT");
    if (modifiers & QtMod.shift) mods.push("SHIFT");
    if (modifiers & QtMod.meta) mods.push("SUPER");
    if (!mods.length && key === Qt.escape)
        return { cancel: true };
    if (!mods.length && (key === Qt.backspace || key === Qt.delete))
        return { clear: true };

    let name = "";
    if (scanCode >= 10 && scanCode <= 19)
        name = String((scanCode - 9) % 10);
    else if (key >= 0x41 && key <= 0x5a)
        name = String.fromCharCode(key);
    else if (key >= 0x30 && key <= 0x39)
        name = String.fromCharCode(key);
    else if (key >= Qt.f1 && key <= Qt.f24)
        name = "F" + (key - Qt.f1 + 1);
    else if (NAMED.has(key))
        name = NAMED.get(key);
    else if (PUNCTUATION.has(key) && !mods.includes("SHIFT"))
        name = PUNCTUATION.get(key);
    if (!name)
        return { error: "key" };
    // Plain keys would stop typing them: only function keys and Print go alone.
    if (!mods.length && !/^F\d+$/.test(name) && name !== "Print")
        return { error: "modifier" };
    return { keys: mods.concat([name]).join(" + ") };
}

/** A bind from `hyprctl binds -j` as keys (keycode binds as "code:N"). */
export function fromBind(modmask, key, keycode) {
    const mods = ORDER.filter(m => modmask & Mod[m]);
    const name = key || (keycode ? "code:" + keycode : "");
    return mods.concat(name ? [name] : []).join(" + ");
}

/** { mods: bitmask, key } with the key's case folded, for comparing. */
export function parse(keys) {
    let mods = 0;
    let key = "";
    for (const part of String(keys).split("+").map(s => s.trim()).filter(s => s.length)) {
        const m = Mod[part.toUpperCase()] ?? (part.toUpperCase() === "CONTROL" ? Mod.CTRL : 0);
        if (m)
            mods |= m;
        else
            key = part.toLowerCase();
    }
    return { mods, key };
}

/** Whether two shortcuts are the same keys. */
export function same(a, b) {
    if (!a || !b)
        return false;
    const x = parse(a);
    const y = parse(b);
    return x.mods === y.mods && x.key === y.key;
}

const KEY_LABELS = {
    left: "←", right: "→", up: "↑", down: "↓", grave: "`", minus: "-", equal: "=",
    comma: ",", period: ".", slash: "/", semicolon: ";", apostrophe: "'",
    bracketleft: "[", bracketright: "]", backslash: "\\", tab: "Tab", escape: "Esc",
    page_up: "RePág", page_down: "AvPág", home: "Inicio", end: "Fin", insert: "Insert",
};
/** Labels that read differently per language: Settings passes a translator for `keys.cap.<name>`. */
const TRANSLATED = new Set(["space", "return", "print", "backspace", "delete", "shift",
    "mouse:272", "mouse:273", "mouse_up", "mouse_down", "code:64",
    "xf86audioraisevolume", "xf86audiolowervolume", "xf86audiomute", "xf86monbrightnessup",
    "xf86monbrightnessdown", "xf86audioplay", "xf86audionext", "xf86audioprev"]);
const CAP_KEY = name => name.replace(/[^a-z0-9]/g, "");

/**
 * The keycaps for a shortcut, modifiers first: ["Super", "Shift", "Q"].
 * `tr(name)` translates a label key (keys.cap.<name>).
 */
export function caps(keys, tr) {
    const { mods } = parse(keys);
    const out = [];
    for (const m of ORDER)
        if (mods & Mod[m])
            out.push(m === "SHIFT" ? tr("shift") : m === "SUPER" ? "Super" : m === "CTRL" ? "Ctrl" : "Alt");
    const raw = String(keys).split("+").map(s => s.trim()).filter(s => s.length && !Mod[s.toUpperCase()]).pop() ?? "";
    const name = raw.toLowerCase();
    if (!name)
        return out;
    if (TRANSLATED.has(name))
        out.push(tr(CAP_KEY(name)));
    else if (KEY_LABELS[name])
        out.push(KEY_LABELS[name]);
    else
        out.push(raw.length === 1 ? raw.toUpperCase() : raw);
    return out;
}

/** The labels `caps` asks the translator for (for the i18n checker's list). */
export const translatedCaps = ["shift"].concat([...TRANSLATED].filter(n => n !== "shift").map(CAP_KEY));
