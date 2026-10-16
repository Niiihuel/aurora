// node shell/core/search.test.mjs — run by `nix flake check` too.
import assert from "node:assert/strict";
import { score, rank, calculate } from "./search.mjs";

// Prefix beats word start beats substring beats letters in order; none is 0.
assert.ok(score("Firefox", "fir") > score("Mozilla Firefox", "fir"));
assert.ok(score("Mozilla Firefox", "fir") > score("Spotify", "tif"));
assert.ok(score("Spotify", "tif") > score("Visual Studio Code", "vsc"));
assert.ok(score("Visual Studio Code", "vsc") > 0);
assert.equal(score("Kitty", "xyz"), 0);
assert.equal(score("Kitty", ""), 0);
// Accents and case don't matter.
assert.ok(score("Música", "musica") >= 90);

// Ranking: the name counts more than keywords; uses nudge favorites up.
const apps = [
    { name: "Files", alt: "file manager browser", uses: 0 },
    { name: "Firefox", alt: "web browser", uses: 0 },
    { name: "Chrome", alt: "web browser", uses: 30 },
];
assert.equal(rank(apps, "fi", 5)[0].name, "Files");
assert.deepEqual(rank(apps, "browser", 5).map(a => a.name), ["Chrome", "Files", "Firefox"]);
assert.equal(rank(apps, "zzz", 5).length, 0);
// Scattered letters only count in the name, not in descriptions.
assert.equal(score("Document Editor", "disc", true), 0);
assert.deepEqual(rank([{ name: "Discord", alt: "chat" }, { name: "ONLYOFFICE", alt: "Document Editor" }], "disc", 5).map(a => a.name), ["Discord"]);

// Calculator: arithmetic only.
assert.equal(calculate("2+2"), 4);
assert.equal(calculate("2 ^ 10"), 1024);
assert.equal(calculate("1,5 * 2"), 3);
assert.equal(calculate("(3+4)*2 % 5"), 4);
assert.equal(calculate("42"), null);          // a number alone isn't a calculation
assert.equal(calculate("-5"), null);
assert.equal(calculate("firefox"), null);
assert.equal(calculate("alert(1)"), null);
assert.equal(calculate("1/0"), null);          // not finite
assert.equal(calculate("2+"), null);           // syntax error

console.log("search ok");
