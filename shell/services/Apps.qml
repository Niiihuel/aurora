pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/search.mjs" as Search

/**
 * The installed applications for the launcher, searched with core/search.mjs
 * and nudged by how often each was opened (counts persisted in
 * $XDG_STATE_HOME/aurora/launches.json).
 */
Singleton {
    id: root

    readonly property var entries: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    function iconFor(entry) {
        if (!entry || !entry.icon)
            return "";
        // Some apps name a file instead of a themed icon; others only ship a
        // pixmap. A missing one fails to load and the launcher draws a glyph.
        // shortcut: the pixmaps dir is NixOS's system profile; upgrade if apps come from elsewhere.
        if (entry.icon.startsWith("/"))
            return "file://" + entry.icon;
        return Quickshell.iconPath(entry.icon, true) || "file:///run/current-system/sw/share/pixmaps/" + entry.icon + ".png";
    }

    /** Best matches for `query`; with no query, the most used apps. */
    function search(query, limit) {
        const counts = launches.counts || {};
        const apps = entries.map(e => ({
            entry: e,
            name: e.name,
            alt: [e.genericName, (e.keywords || []).join(" "), e.id].join(" "),
            uses: counts[e.id] || 0
        }));
        if (!query.trim().length)
            return apps.filter(a => a.uses > 0).sort((a, b) => b.uses - a.uses).slice(0, limit).map(a => a.entry);
        return Search.rank(apps, query, limit).map(a => a.entry);
    }

    function launch(entry) {
        const counts = Object.assign({}, launches.counts || {});
        counts[entry.id] = (counts[entry.id] || 0) + 1;
        launches.counts = counts;
        entry.execute();
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aurora/launches.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: launches
            property var counts: ({})
        }
    }
}
