// node shell/core/activity.test.mjs — run by `nix flake check` too.
import assert from "node:assert/strict";
import { cpuTimes, cpuLoad, memory, netBytes, cleanName, processes, groups, top } from "./activity.mjs";

// CPU: idle and iowait don't count as busy.
const a = cpuTimes("cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 1 2 3\n");
assert.deepEqual(a, { busy: 200, total: 1000 });
const b = cpuTimes("cpu  200 0 200 1300 300 0 0 0 0 0\n");
assert.equal(cpuLoad(a, b), 0.2);
assert.equal(cpuLoad(a, a), 0);

// Memory: used is what isn't available; swap from total minus free.
const m = memory("MemTotal:       1000 kB\nMemFree: 100 kB\nMemAvailable:    400 kB\nSwapTotal: 50 kB\nSwapFree: 20 kB\n");
assert.deepEqual(m, { used: 600 * 1024, total: 1000 * 1024, swapUsed: 30 * 1024, swapTotal: 50 * 1024 });

// Network: loopback and bridges are skipped.
const dev = `Inter-|   Receive |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets
    lo: 999 1 0 0 0 0 0 0 999 1 0 0 0 0 0 0
wlp3s0: 1000 10 0 0 0 0 0 0 500 5 0 0 0 0 0 0
docker0: 77 1 0 0 0 0 0 0 77 1 0 0 0 0 0 0
  eth0: 10 1 0 0 0 0 0 0 20 1 0 0 0 0 0 0`;
assert.deepEqual(netBytes(dev), { rx: 1010, tx: 520 });

// NixOS wrappers, whole or cut to 15 characters, read as the program.
assert.equal(cleanName(".kitty-wrapped"), "kitty");
assert.equal(cleanName(".quickshell-wra"), "quickshell");
assert.equal(cleanName(".gnome-keyring-"), "gnome-keyring");
assert.equal(cleanName(".xdg-desktop-po"), "xdg-desktop-po");
assert.equal(cleanName("Isolated Web Co"), "Isolated Web Co");

// Processes: names with spaces and parentheses survive; helpers group by name.
const line = (pid, name, ticks, threads, rss, tty = 0) =>
    `${pid} (${name}) S 1 1 1 ${tty} -1 0 0 0 0 0 ${ticks} 0 0 0 20 0 ${threads} 0 100 0 ${rss} 0`;
const t0 = processes([line(1, "Isolated Web Co", 100, 20, 10), line(2, "Isolated Web Co", 50, 10, 5), line(3, "a (b) c", 0, 1, 1)].join("\n"));
assert.deepEqual(t0.get(3), { name: "a (b) c", ticks: 0, threads: 1, rss: 4096, tty: false });
const t1 = processes([line(1, "Isolated Web Co", 300, 20, 10), line(2, "Isolated Web Co", 150, 10, 5), line(3, "a (b) c", 50, 1, 1), line(4, "new", 999, 1, 1), line(5, ".kitty-wrapped", 0, 1, 1), line(6, "kitty", 0, 1, 1, 34817)].join("\n"));
const g = groups(t0, t1, 2);
const web = g.find(r => r.name === "Isolated Web Co");
assert.deepEqual(web.pids, [1, 2]);
assert.equal(web.cpu, 1.5); // 300 ticks over 2 s at 100 Hz: one and a half cores
assert.equal(web.rss, 15 * 4096);
assert.equal(web.threads, 30);
assert.equal(g.find(r => r.name === "new").cpu, 0); // no baseline yet
assert.deepEqual(g.find(r => r.name === "kitty").pids, [5, 6]); // the wrapper and the program are one row
assert.equal(g.find(r => r.name === "kitty").tty, true); // one of them runs in a terminal
assert.equal(web.tty, false);
assert.deepEqual(top(g, "cpu", 2).map(r => r.name), ["Isolated Web Co", "a (b) c"]);
assert.equal(top(g, "rss", 1)[0].name, "Isolated Web Co");

console.log("activity: ok");
