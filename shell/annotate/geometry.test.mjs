// node shell/annotate/geometry.test.mjs — run by `nix flake check` too.
import assert from "node:assert/strict";
import * as G from "./geometry.mjs";

const sel = { x: 100, y: 100, width: 200, height: 100 };
assert.deepEqual(G.clampPoint(50, 150, sel), [100, 150]);
assert.deepEqual(G.clampPoint(400, 400, sel), [300, 200]);

assert.deepEqual(G.box({ x1: 50, y1: 40, x2: 10, y2: 20 }), { x: 10, y: 20, width: 40, height: 20 });

// Too small to keep.
assert.ok(!G.worthKeeping({ type: "line", x1: 0, y1: 0, x2: 3, y2: 0 }));
assert.ok(G.worthKeeping({ type: "arrow", x1: 0, y1: 0, x2: 5, y2: 0 }));
assert.ok(!G.worthKeeping({ type: "rect", x1: 0, y1: 0, x2: 10, y2: 2 }));
assert.ok(G.worthKeeping({ type: "blur", x1: 0, y1: 0, x2: 3, y2: 3 }));
assert.ok(!G.worthKeeping({ type: "pen", points: [[0, 0]] }));
assert.ok(!G.worthKeeping({ type: "text", text: "" }));

// Steps count up from the highest; a deleted one leaves a gap.
assert.equal(G.nextStep([]), 1);
assert.equal(G.nextStep([{ type: "step", n: 1 }, { type: "rect" }, { type: "step", n: 3 }]), 4);
assert.equal(G.stepDiameter(4), 32);
assert.equal(G.textSize(4), 28);

// The arrowhead's tip is the arrow's tip; its sides are max(w*5, 22).
const arrow = { type: "arrow", width: 4, x1: 0, y1: 0, x2: 100, y2: 0 };
const [tip, l, r] = G.arrowHead(arrow);
assert.deepEqual(tip, [100, 0]);
assert.ok(Math.abs(Math.hypot(l[0] - 100, l[1]) - 22) < 1e-9);
assert.ok(l[1] * r[1] < 0);

// Picking: topmost first, with tolerance.
const list = [
    { type: "rect", width: 4, x1: 0, y1: 0, x2: 50, y2: 50 },
    { type: "line", width: 4, x1: 0, y1: 100, x2: 100, y2: 100 },
    { type: "step", width: 4, n: 1, x1: 25, y1: 25 },
];
assert.equal(G.pick(list, 25, 25), 2);
assert.equal(G.pick(list, 5, 5), 0);
assert.equal(G.pick(list, 50, 105), 1);
assert.equal(G.pick(list, 300, 300), -1);
assert.ok(G.hits({ type: "ellipse", width: 4, x1: 0, y1: 0, x2: 100, y2: 50 }, 50, 25));
assert.ok(!G.hits({ type: "ellipse", width: 4, x1: 0, y1: 0, x2: 100, y2: 50 }, 2, 2));
assert.ok(G.hits({ type: "pen", width: 4, points: [[0, 0], [10, 10], [20, 0]] }, 15, 6));

// Moving keeps shape; pen points move too.
const m = G.moved({ type: "pen", x1: 0, y1: 0, points: [[0, 0], [5, 5]] }, 10, 20);
assert.deepEqual(m.points, [[10, 20], [15, 25]]);

// Paths.
assert.equal(G.path({ type: "rect", x1: 10, y1: 10, x2: 0, y2: 0 }), "M 0 0 H 10 V 10 H 0 Z");
assert.equal(G.path({ type: "pen", points: [[1, 2], [3, 4]] }), "M 1 2 L 3 4");

// Resizing never inverts.
assert.deepEqual(G.resized({ x: 0, y: 0, width: 100, height: 100 }, "se", 10, 20), { x: 0, y: 0, width: 110, height: 120 });
assert.deepEqual(G.resized({ x: 0, y: 0, width: 100, height: 100 }, "w", 200, 0), { x: 92, y: 0, width: 8, height: 100 });

// Hex colors.
assert.equal(G.parseHex("#F0a"), "#ff00aa");
assert.equal(G.parseHex("0a84ff"), "#0a84ff");
assert.equal(G.parseHex("#12345"), "");

console.log("annotate geometry ok");
