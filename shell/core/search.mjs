// Launcher search: fuzzy matching for app names and a safe calculator.
// Plain JS so QML imports it and node tests it (search.test.mjs).

/** Lowercase without accents, so "música" matches "musica". */
export function fold(s) {
    return String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

/**
 * How well `text` matches `query`, 0 (not at all) to 100: the whole text
 * starting with it beats a word starting with it, beats containing it,
 * beats having its letters in order (fewer gaps first). `strict` drops the
 * last kind: letters scattered through a description match almost anything.
 */
export function score(text, query, strict) {
    const t = fold(text), q = fold(query).trim();
    if (!q.length || !t.length)
        return 0;
    if (t.startsWith(q))
        return 100 - Math.min(20, t.length - q.length);
    if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
        return 80;
    if (t.includes(q))
        return 60;
    if (strict)
        return 0;
    let at = 0, gaps = 0;
    for (const c of q) {
        const i = t.indexOf(c, at);
        if (i < 0)
            return 0;
        gaps += i - at;
        at = i + 1;
    }
    return Math.max(1, 40 - gaps);
}

/**
 * Rank apps for `query`. Each app is { name, alt (generic name, keywords…),
 * uses (launch count) }; returns the matching ones best first. The name
 * counts fully, the rest at 60%; how often an app was launched breaks ties
 * and nudges favorites up.
 */
export function rank(apps, query, limit) {
    const scored = [];
    for (const app of apps) {
        const s = Math.max(score(app.name, query), 0.6 * score(app.alt, query, true));
        if (s > 0)
            scored.push({ app, s: s + 8 * Math.log1p(app.uses || 0) });
    }
    scored.sort((a, b) => b.s - a.s || String(a.app.name).localeCompare(String(b.app.name)));
    return scored.slice(0, limit).map(x => x.app);
}

/**
 * The value of an arithmetic expression, or null when `text` isn't one.
 * Only digits, + - * / % ^ ( ) and decimal points or commas get through, so
 * the evaluation can't run anything else; "^" is a power, "," a decimal point.
 */
export function calculate(text) {
    const expr = String(text || "").trim();
    if (!/^[\d\s+\-*/%^().,]+$/.test(expr) || !/\d/.test(expr) || !/[+\-*/%^]/.test(expr.replace(/^\s*-/, "")))
        return null;
    try {
        const value = Function(`"use strict"; return (${expr.replace(/,/g, ".").replace(/\^/g, "**")});`)();
        return typeof value === "number" && Number.isFinite(value) ? value : null;
    } catch (e) {
        return null;
    }
}
