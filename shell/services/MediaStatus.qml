pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/**
 * What's playing, for Control Center's Now Playing module: the MPRIS player
 * that is playing (else the first one), its track and the transport actions.
 */
Singleton {
    id: root

    readonly property var player: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? all[0] ?? null;
    }
    readonly property bool present: !!player
    readonly property bool playing: !!player && player.isPlaying
    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    /** The app playing, e.g. "Spotify" or "Firefox". */
    readonly property string app: player ? (player.identity || "") : ""

    /** Seconds; length is 0 when the player doesn't say. */
    // Live streams report absurd lengths (Chrome: years); treat those as unknown.
    readonly property real length: player && player.lengthSupported && player.length < 7 * 86400 ? player.length : 0
    property real position: 0
    readonly property bool canSeek: !!player && player.canSeek && length > 0

    function seek(fraction) {
        if (!canSeek)
            return;
        player.position = Math.max(0, Math.min(1, fraction)) * length;
        position = player.position;
    }

    /** "3:07" for a position in seconds. */
    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    /** How many views show the position (Control Center's media page); the clock runs only for them. */
    property int watchers: 0
    onWatchersChanged: if (watchers > 0 && player && player.positionSupported) position = player.position

    // MPRIS doesn't push the position while playing; read it once a second,
    // and only while it's on screen.
    Timer {
        running: root.watchers > 0 && root.playing && root.player.positionSupported
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player.position
    }
    onPlayerChanged: position = player && player.positionSupported ? player.position : 0

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }
    function next() {
        if (player && player.canGoNext)
            player.next();
    }
    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }
}
