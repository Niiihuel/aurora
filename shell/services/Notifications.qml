pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../core"

/**
 * aurora's notification server (org.freedesktop.Notifications).
 *
 * Every notification stays in `all` (newest first) for the Notification
 * Center until it's dismissed; new ones also show as banners (`banners`,
 * newest first, at most three) unless Do Not Disturb is on — critical ones
 * always show, as macOS lets time-sensitive ones through. Arrival plays the
 * freedesktop sound theme through PipeWire, honoring the spec's
 * `suppress-sound`, `sound-file` and `sound-name` hints.
 *
 * The banner view decides when a banner leaves (its timer pauses under the
 * pointer) and calls `hideBanner`; the notification itself stays.
 */
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values.slice().reverse()
    property var banners: []
    /** Notification id → arrival time (ms), for "now" / "5 min ago". */
    property var arrivals: ({})

    /** Seconds a banner stays: the sender's timeout if it gave one, else 5 s; 0 = until dismissed. */
    function bannerSeconds(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.expireTimeout > 0 ? Math.max(3, n.expireTimeout / 1000) : 5;
    }

    function hideBanner(n) {
        banners = banners.filter(b => b !== n);
    }

    function dismiss(n) {
        hideBanner(n);
        n.dismiss();
    }

    function clearAll() {
        banners = [];
        for (const n of all.slice())
            n.dismiss();
    }

    /** Clicking a notification: run its default action (opens the app), then it's done. */
    function activate(n) {
        const action = n.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        if (!n.resident)
            dismiss(n);
        else
            hideBanner(n);
    }

    /** The other actions, shown as buttons. */
    function buttons(n) {
        return n.actions.filter(a => a.identifier !== "default" && a.text.trim().length > 0);
    }

    /** "now", "5 min ago", or the time of day. */
    function age(n, now) {
        const at = arrivals[n.id] ?? now;
        const minutes = Math.floor((now - at) / 60000);
        if (minutes < 1)
            return I18n.tr("notifications.now");
        if (minutes < 60)
            return I18n.tr("notifications.minutesAgo", { n: minutes });
        return I18n.locale.toString(new Date(at), "H:mm");
    }

    /** Icon for the app that sent it: its desktop entry's icon, else whatever it named. */
    function appIcon(n) {
        const entry = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName);
        // notify-send -i <name> arrives as the image "image://icon/<name>": that's the app's icon.
        const named = (n.image || "").startsWith("image://icon/") ? n.image.slice(13) : "";
        const name = entry && entry.icon ? entry.icon : n.appIcon || named;
        if (!name)
            return "";
        if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:"))
            return name.startsWith("/") ? "file://" + name : name;
        // Same rule as the launcher (Apps.iconFor): the theme, else a pixmap;
        // a missing file fails to load and the card shows a bell.
        return Quickshell.iconPath(name, true) || "file:///run/current-system/sw/share/pixmaps/" + name + ".png";
    }

    function chime(n, critical) {
        const hints = n.hints || {};
        if (!Settings.notificationSounds || hints["suppress-sound"])
            return;
        const dir = "/run/current-system/sw/share/sounds/freedesktop/stereo/";
        const file = hints["sound-file"] ? String(hints["sound-file"])
            : hints["sound-name"] ? dir + hints["sound-name"] + ".oga"
            : dir + (critical ? "dialog-warning.oga" : "message-new-instant.oga");
        Quickshell.execDetached(["sh", "-c", "pw-play \"$1\" 2>/dev/null || pw-play \"$2\"", "_", file, dir + "message-new-instant.oga"]);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            // Closed by the sender (or expired there): drop its banner too.
            n.closed.connect(() => root.hideBanner(n));
            root.arrivals = Object.assign({}, root.arrivals, { [n.id]: Date.now() });
            const critical = n.urgency === NotificationUrgency.Critical;
            // Carried over a hot reload: already seen, history only.
            if (n.lastGeneration)
                return;
            if (Settings.doNotDisturb && !critical)
                return;
            root.banners = [n].concat(root.banners.filter(b => b.id !== n.id)).slice(0, 3);
            root.chime(n, critical);
        }
    }
}
