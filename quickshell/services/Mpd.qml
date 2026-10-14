pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// mpd library for the music launcher, loaded with `mpc` in the background.
// refresh() reloads it; the previous lists stay usable until new ones arrive.
Singleton {
    id: root

    property var songs: []
    property var artists: []
    property var albums: []
    property var playlists: []

    function refresh(): void {
        for (const p of [songsProc, artistsProc, albumsProc, playlistsProc])
            p.running = true;
    }

    function lines(text: string): var {
        return text.split("\n").map(l => l.trim()).filter(l => l);
    }

    // "Artist/Album/01 - Song.flac" -> "Artist - Song"
    function trackLabel(path: string): string {
        const parts = path.split("/");
        const file = parts[parts.length - 1];
        const song = file.replace(/\.[^.]+$/, "").replace(/^\d+[\s\-.]+/, "");
        return parts.length >= 2 ? `${parts[0]} - ${song}` : song;
    }

    // Same mpc sequences as the Ignis launcher; names are passed as arguments,
    // never interpolated into the script.
    function run(script: string, arg: string): void {
        Quickshell.execDetached(["sh", "-c", script, "sh", arg]);
    }

    // Queue after the current song and skip to it (when stopped, `next` fails
    // and insert appends, so play the last queue position instead).
    function playSong(path: string): void {
        run('mpc insert "$1" && { mpc next || mpc play "$(mpc playlist | wc -l)"; } >/dev/null 2>&1 && notify-send "Playing $1"', path);
    }
    // Append the artist and jump to its first track.
    function playArtist(name: string): void {
        run('pos=$(($(mpc playlist | wc -l) + 1)); mpc findadd artist "$1" && mpc play "$pos" >/dev/null && notify-send "Playing artist $1"', name);
    }
    function playAlbum(name: string): void {
        run('mpc clear && mpc findadd album "$1" && mpc play && notify-send "Playing album $1"', name);
    }
    function playPlaylist(name: string): void {
        run('mpc clear && mpc load "$1" && mpc play && notify-send "Playing playlist $1"', name);
    }

    Process {
        id: songsProc
        command: ["mpc", "listall"]
        stdout: StdioCollector { onStreamFinished: root.songs = root.lines(text) }
    }
    Process {
        id: artistsProc
        command: ["mpc", "list", "artist"]
        stdout: StdioCollector { onStreamFinished: root.artists = root.lines(text) }
    }
    Process {
        id: albumsProc
        command: ["mpc", "list", "album"]
        stdout: StdioCollector { onStreamFinished: root.albums = root.lines(text) }
    }
    Process {
        id: playlistsProc
        command: ["mpc", "lsplaylists"]
        stdout: StdioCollector { onStreamFinished: root.playlists = root.lines(text) }
    }
}
