// Geometry for the screenshot editor's annotations, pure so it's tested with
// node (geometry.test.mjs). An annotation is a plain object:
//   { type, color, width, filled, x1, y1, x2, y2, points, text, size, n, zoom }
// in the screen's logical points. Box-like types use x1/y1/x2/y2 as two
// corners (any order); line and arrow use them as tail and tip; pen uses
// `points` ([x, y] pairs); text and step use x1/y1 as their anchor.

/** Types drawn as a dragged box. */
export const BOXES = ["rect", "ellipse", "marker", "blur", "pixelate", "zoom"];
/** Types that read the screenshot under them (drawn first, under vectors). */
export const EFFECTS = ["blur", "pixelate", "zoom"];

export function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

/** A point kept inside a rect {x, y, width, height}. */
export function clampPoint(x, y, r) {
    return [clamp(x, r.x, r.x + r.width), clamp(y, r.y, r.y + r.height)];
}

/** The normalized box of two corners. */
export function box(a) {
    return {
        x: Math.min(a.x1, a.x2),
        y: Math.min(a.y1, a.y2),
        width: Math.abs(a.x2 - a.x1),
        height: Math.abs(a.y2 - a.y1),
    };
}

/** Whether a draft is big enough to keep. */
export function worthKeeping(a) {
    if (a.type === "line" || a.type === "arrow")
        return Math.hypot(a.x2 - a.x1, a.y2 - a.y1) > 4;
    if (BOXES.includes(a.type))
        return Math.abs(a.x2 - a.x1) > 2 && Math.abs(a.y2 - a.y1) > 2;
    if (a.type === "pen")
        return (a.points ?? []).length >= 2;
    if (a.type === "text")
        return (a.text ?? "").length > 0;
    return true;
}

/** A step's diameter for its width; a text's pixel size for its width. */
export const stepDiameter = width => width * 4 + 16;
export const textSize = width => width * 5 + 8;

/** The next step number: one past the highest (deleting one leaves a gap). */
export function nextStep(list) {
    return list.reduce((m, a) => (a.type === "step" ? Math.max(m, a.n) : m), 0) + 1;
}

/** The arrowhead's three points: tip, then the two back corners. */
export function arrowHead(a) {
    const angle = Math.atan2(a.y2 - a.y1, a.x2 - a.x1);
    const side = Math.max(a.width * 5, 22);
    const spread = 0.45;
    return [
        [a.x2, a.y2],
        [a.x2 - side * Math.cos(angle - spread), a.y2 - side * Math.sin(angle - spread)],
        [a.x2 - side * Math.cos(angle + spread), a.y2 - side * Math.sin(angle + spread)],
    ];
}

/** Where the arrow's shaft stops, so its round cap hides under the head. */
export function arrowShaftEnd(a) {
    const len = Math.hypot(a.x2 - a.x1, a.y2 - a.y1);
    const back = Math.min(len, Math.max(a.width * 5, 22) * Math.cos(0.45) * 0.6);
    const t = len > 0 ? (len - back) / len : 0;
    return [a.x1 + (a.x2 - a.x1) * t, a.y1 + (a.y2 - a.y1) * t];
}

function segmentDistance(px, py, ax, ay, bx, by) {
    const dx = bx - ax;
    const dy = by - ay;
    const len2 = dx * dx + dy * dy;
    const t = len2 > 0 ? clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0, 1) : 0;
    return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

/** The box an annotation takes up (for its selection frame and text). */
export function bounds(a) {
    switch (a.type) {
    case "text": {
        const size = a.size ?? textSize(a.width);
        return { x: a.x1, y: a.y1, width: Math.max(size, (a.text ?? "").length * size * 0.6), height: size * 1.4 };
    }
    case "step": {
        const d = stepDiameter(a.width);
        return { x: a.x1 - d / 2, y: a.y1 - d / 2, width: d, height: d };
    }
    case "pen": {
        const xs = a.points.map(p => p[0]);
        const ys = a.points.map(p => p[1]);
        const x = Math.min(...xs);
        const y = Math.min(...ys);
        return { x, y, width: Math.max(...xs) - x, height: Math.max(...ys) - y };
    }
    default:
        return box(a);
    }
}

/** Whether a point picks this annotation. */
export function hits(a, px, py) {
    const tol = Math.max(a.width || 4, 8);
    switch (a.type) {
    case "line":
    case "arrow":
        return segmentDistance(px, py, a.x1, a.y1, a.x2, a.y2) <= tol;
    case "pen":
        for (let i = 1; i < a.points.length; i++)
            if (segmentDistance(px, py, a.points[i - 1][0], a.points[i - 1][1], a.points[i][0], a.points[i][1]) <= tol)
                return true;
        return false;
    case "step":
        return Math.hypot(px - a.x1, py - a.y1) <= stepDiameter(a.width) / 2 + tol;
    case "ellipse": {
        const b = box(a);
        const rx = b.width / 2 + tol;
        const ry = b.height / 2 + tol;
        const dx = px - (b.x + b.width / 2);
        const dy = py - (b.y + b.height / 2);
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1;
    }
    default: {
        const b = bounds(a);
        return px >= b.x - tol && px <= b.x + b.width + tol && py >= b.y - tol && py <= b.y + b.height + tol;
    }
    }
}

/** The topmost annotation under a point, or -1. */
export function pick(list, px, py) {
    for (let i = list.length - 1; i >= 0; i--)
        if (hits(list[i], px, py))
            return i;
    return -1;
}

/** A copy moved by dx, dy. */
export function moved(a, dx, dy) {
    const out = Object.assign({}, a, { x1: a.x1 + dx, y1: a.y1 + dy, x2: (a.x2 ?? a.x1) + dx, y2: (a.y2 ?? a.y1) + dy });
    if (a.points)
        out.points = a.points.map(p => [p[0] + dx, p[1] + dy]);
    return out;
}

/** SVG path data for the vector types (rect, ellipse, line, arrow shaft, pen). */
export function path(a) {
    switch (a.type) {
    case "rect": {
        const b = box(a);
        return `M ${b.x} ${b.y} H ${b.x + b.width} V ${b.y + b.height} H ${b.x} Z`;
    }
    case "ellipse": {
        const b = box(a);
        const rx = b.width / 2;
        const ry = b.height / 2;
        const cy = b.y + ry;
        return `M ${b.x} ${cy} A ${rx} ${ry} 0 1 0 ${b.x + b.width} ${cy} A ${rx} ${ry} 0 1 0 ${b.x} ${cy} Z`;
    }
    case "line":
        return `M ${a.x1} ${a.y1} L ${a.x2} ${a.y2}`;
    case "arrow": {
        const [ex, ey] = arrowShaftEnd(a);
        return `M ${a.x1} ${a.y1} L ${ex} ${ey}`;
    }
    case "pen":
        return a.points.map((p, i) => `${i ? "L" : "M"} ${p[0]} ${p[1]}`).join(" ");
    default:
        return "";
    }
}

/** SVG path data for an arrowhead. */
export function headPath(a) {
    const [t, l, r] = arrowHead(a);
    return `M ${t[0]} ${t[1]} L ${l[0]} ${l[1]} L ${r[0]} ${r[1]} Z`;
}

/** Edges a resize handle moves, and the resulting rect (min 8 per side). */
export function resized(r, handle, dx, dy, min = 8) {
    let x1 = r.x, y1 = r.y, x2 = r.x + r.width, y2 = r.y + r.height;
    if (handle.includes("w")) x1 = Math.min(x1 + dx, x2 - min);
    if (handle.includes("e")) x2 = Math.max(x2 + dx, x1 + min);
    if (handle.includes("n")) y1 = Math.min(y1 + dy, y2 - min);
    if (handle.includes("s")) y2 = Math.max(y2 + dy, y1 + min);
    return { x: x1, y: y1, width: x2 - x1, height: y2 - y1 };
}

/** "#rgb", "rgb", "#rrggbb" or "rrggbb" as "#rrggbb", or "" if it isn't one. */
export function parseHex(s) {
    const t = String(s).trim().replace(/^#/, "");
    if (/^[0-9a-f]{3}$/i.test(t))
        return "#" + t.split("").map(c => c + c).join("").toLowerCase();
    if (/^[0-9a-f]{6}$/i.test(t))
        return "#" + t.toLowerCase();
    return "";
}
