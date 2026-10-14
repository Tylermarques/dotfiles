pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Picks the player the bar shows: whichever is playing, otherwise the last one
// that played (if still open), otherwise the first player.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer lastActive: null
    readonly property MprisPlayer playing: players.find(p => p.isPlaying) ?? null
    readonly property MprisPlayer active: playing
        ?? (players.includes(lastActive) ? lastActive : players[0] ?? null)

    // Track from `playing`, not `active`, so lastActive isn't part of its own binding.
    onPlayingChanged: if (playing) lastActive = playing

    function label(p: MprisPlayer): string {
        if (!p) return "";
        if (p.trackTitle && p.trackArtist) return `${p.trackArtist} - ${p.trackTitle}`;
        return p.trackTitle || p.trackArtist || "Unknown";
    }
}
