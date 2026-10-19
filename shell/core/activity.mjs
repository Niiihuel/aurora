// Parsers for services/ActivityStatus: /proc and /sys text in, numbers out.

/** /proc/stat's first line → { busy, total } jiffies since boot. */
export function cpuTimes(stat) {
    const f = stat.slice(0, stat.indexOf("\n")).trim().split(/\s+/).slice(1).map(Number);
    const total = f.slice(0, 8).reduce((a, b) => a + b, 0);
    // idle + iowait
    return { busy: total - f[3] - (f[4] || 0), total };
}

/** Busy share (0–1) between two cpuTimes samples. */
export function cpuLoad(before, after) {
    const total = after.total - before.total;
    return total > 0 ? Math.max(0, Math.min(1, (after.busy - before.busy) / total)) : 0;
}

/** /proc/meminfo → bytes used and total, memory and swap. */
export function memory(meminfo) {
    const kb = {};
    for (const line of meminfo.split("\n")) {
        const m = /^(\w+):\s+(\d+)/.exec(line);
        if (m)
            kb[m[1]] = Number(m[2]);
    }
    const k = name => (kb[name] || 0) * 1024;
    return {
        used: k("MemTotal") - k("MemAvailable"),
        total: k("MemTotal"),
        swapUsed: k("SwapTotal") - k("SwapFree"),
        swapTotal: k("SwapTotal")
    };
}

// Bridges and virtual links would count the same traffic twice.
const virtualLink = /^(lo|docker|veth|br-|virbr|tailscale|tun|tap|wg)/;

/** /proc/net/dev → total bytes received and sent on physical links. */
export function netBytes(dev) {
    let rx = 0, tx = 0;
    for (const line of dev.split("\n").slice(2)) {
        const colon = line.indexOf(":");
        if (colon < 0 || virtualLink.test(line.slice(0, colon).trim()))
            continue;
        const f = line.slice(colon + 1).trim().split(/\s+/).map(Number);
        rx += f[0];
        tx += f[8];
    }
    return { rx, tx };
}

/**
 * A process name as people know it. NixOS runs programs through wrappers
 * named ".kitty-wrapped", which the kernel cuts to 15 characters
 * (".quickshell-wra").
 */
export function cleanName(name) {
    const m = /^\.(.+?)-(w|wr|wra|wrap|wrapp|wrappe|wrapped)?$/.exec(name);
    return m ? m[1] : name.replace(/^\./, "");
}

/**
 * Concatenated /proc/<pid>/stat lines → Map pid → { name, ticks, threads, rss, tty }.
 * The name sits in parentheses and may hold spaces or ")", so fields are
 * counted from the last ")".
 */
export function processes(stats, pageSize = 4096) {
    const all = new Map();
    for (const line of stats.split("\n")) {
        const close = line.lastIndexOf(")");
        if (close < 0)
            continue;
        const pid = Number(line.slice(0, line.indexOf(" ")));
        const f = line.slice(close + 2).split(" ");
        // Fields 7 (tty), 14/15 (utime, stime), 20 (threads) and 24 (rss) of proc(5), from field 3 on.
        all.set(pid, {
            name: cleanName(line.slice(line.indexOf("(") + 1, close)),
            ticks: Number(f[11]) + Number(f[12]),
            threads: Number(f[17]),
            rss: Number(f[21]) * pageSize,
            tty: f[4] !== "0"
        });
    }
    return all;
}

/**
 * Two processes() samples `seconds` apart → one row per name (helpers of one
 * app share it), like Activity Monitor's % CPU: 1 = one core busy, so it can
 * pass 1 on a multi-core machine. Rows: { name, pids, cpu, rss, threads, tty },
 * `tty` when one of them runs in a terminal.
 */
export function groups(before, after, seconds, hz = 100) {
    const byName = new Map();
    for (const [pid, p] of after) {
        const prev = before.get(pid);
        // A new pid (or a reused one) has no baseline yet.
        const ticks = prev && prev.name === p.name ? Math.max(0, p.ticks - prev.ticks) : 0;
        let g = byName.get(p.name);
        if (!g)
            byName.set(p.name, g = { name: p.name, pids: [], cpu: 0, rss: 0, threads: 0, tty: false });
        g.pids.push(pid);
        g.cpu += seconds > 0 ? ticks / hz / seconds : 0;
        g.rss += p.rss;
        g.threads += p.threads;
        g.tty = g.tty || p.tty;
    }
    return [...byName.values()];
}

/** The top `n` rows by `key` ("cpu" or "rss"). */
export function top(rows, key, n) {
    return rows.slice().sort((a, b) => b[key] - a[key]).slice(0, n);
}
