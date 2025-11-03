import asyncio
import os
import re
import shlex
from ignis import widgets
from ignis.window_manager import WindowManager
from ignis import utils

window_manager = WindowManager.get_default()


def _format_track_display(track_path: str) -> str:
    """
    Format a track path into a friendly display name: "Artist - Song"

    Example:
        "Led Zeppelin/IV/01-Stairway to Heaven.mp3" -> "Led Zeppelin - Stairway to Heaven"
    """
    # Split the path into components
    parts = track_path.split("/")

    if len(parts) >= 2:
        # Extract artist (first directory) and filename (last component)
        artist = parts[0]
        filename = parts[-1]
    else:
        # If no directory structure, just use the filename
        artist = None
        filename = parts[0]

    # Remove file extension
    song_name = os.path.splitext(filename)[0]

    # Strip leading track numbers (e.g., "01-", "01. ", "1-", "1. ")
    song_name = re.sub(r"^\d+[\s\-\.]+", "", song_name)

    # Format and return
    if artist:
        return f"{artist} - {song_name}"
    else:
        return song_name


class MusicTrackItem(widgets.Button):
    def __init__(self, track_path: str, display_text: str) -> None:
        self._track_path = track_path  # Original path for mpc commands
        super().__init__(
            on_click=lambda x: self.play(),
            css_classes=["music-track"],
            child=widgets.Box(
                child=[
                    widgets.Icon(
                        icon_name="audio-x-generic-symbolic",
                        pixel_size=32,
                        style="margin-right: 0.75rem;",
                    ),
                    widgets.Label(
                        label=display_text,  # Formatted display text
                        ellipsize="end",
                        max_width_chars=60,
                        css_classes=["music-track-label"],
                    ),
                ]
            ),
        )

    def play(self) -> None:
        # Close the music launcher window immediately
        window_manager.close_window("ignis_MUSIC_LAUNCHER")

        # Escape track path for safe shell execution
        escaped_track = shlex.quote(self._track_path)

        # Execute mpc commands asynchronously to avoid UI freeze
        command = f'mpc insert {escaped_track} && mpc next >/dev/null && notify-send "Playing {escaped_track}"'
        asyncio.create_task(utils.exec_sh_async(command))


class MusicLauncher(widgets.Window):
    def __init__(self):
        self._all_tracks = []
        self._track_list = widgets.Box(
            vertical=True, visible=False, style="margin-top: 1rem;"
        )
        self._entry = widgets.Entry(
            hexpand=True,
            placeholder_text="Search music library",
            css_classes=["music-search"],
            on_change=self.__search,
            on_accept=self.__on_accept,
        )

        main_box = widgets.Box(
            vertical=True,
            valign="start",
            halign="center",
            css_classes=["music-launcher"],
            child=[
                widgets.Box(
                    css_classes=["music-search-box"],
                    child=[
                        widgets.Icon(
                            icon_name="folder-music-symbolic",
                            pixel_size=24,
                            style="margin-right: 0.5rem;",
                        ),
                        self._entry,
                    ],
                ),
                self._track_list,
            ],
        )

        super().__init__(
            namespace="ignis_MUSIC_LAUNCHER",
            visible=False,
            popup=True,
            kb_mode="on_demand",
            css_classes=["unset"],
            setup=lambda self: self.connect("notify::visible", self.__on_open),
            anchor=["top", "right", "bottom", "left"],
            child=widgets.Overlay(
                child=widgets.Button(
                    vexpand=True,
                    hexpand=True,
                    can_focus=False,
                    css_classes=["unset"],
                    on_click=lambda x: window_manager.close_window(
                        "ignis_MUSIC_LAUNCHER"
                    ),
                    style="background-color: rgba(0, 0, 0, 0.3);",
                ),
                overlays=[main_box],
            ),
        )

        # Load music library on initialization
        self.__load_tracks()

    def __load_tracks(self) -> None:
        """Load all tracks from mpc listall"""
        result = utils.exec_sh("mpc listall")
        if result.stdout:
            self._all_tracks = [
                track.strip() for track in result.stdout.split("\n") if track.strip()
            ]

    def __on_open(self, *args) -> None:
        if not self.visible:
            return

        self._entry.text = ""
        self._entry.grab_focus()
        # Reload tracks when window opens (in case library changed)
        self.__load_tracks()

    def __on_accept(self, *args) -> None:
        if len(self._track_list.child) > 0:
            self._track_list.child[0].play()

    def __search(self, *args) -> None:
        query = self._entry.text.lower()

        if query == "":
            self._entry.grab_focus()
            self._track_list.visible = False
            return

        # Filter tracks based on query (search in both path and formatted display)
        filtered_tracks = [
            track
            for track in self._all_tracks
            if query in track.lower() or query in _format_track_display(track).lower()
        ]

        if not filtered_tracks:
            self._track_list.visible = False
            self._track_list.child = [
                widgets.Label(
                    label="No tracks found",
                    css_classes=["music-no-results"],
                    style="padding: 1rem;",
                )
            ]
            self._track_list.visible = True
        else:
            self._track_list.visible = True
            # Show up to 20 results with formatted display
            self._track_list.child = [
                MusicTrackItem(track, _format_track_display(track))
                for track in filtered_tracks[:20]
            ]
