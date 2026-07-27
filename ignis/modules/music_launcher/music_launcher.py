import asyncio
import os
import re
import shlex
from ignis import widgets
from ignis.window_manager import WindowManager
from ignis import utils
from gi.repository import Gtk, Gdk

window_manager = WindowManager.get_default()

SEARCH_MODES = ["All Songs", "Artists", "Albums", "Playlists"]


def _format_track_display(track_path: str) -> str:
    parts = track_path.split("/")

    if len(parts) >= 2:
        artist = parts[0]
        filename = parts[-1]
    else:
        artist = None
        filename = parts[0]

    song_name = os.path.splitext(filename)[0]
    song_name = re.sub(r"^\d+[\s\-\.]+", "", song_name)

    if artist:
        return f"{artist} - {song_name}"
    else:
        return song_name


class MusicTrackItem(widgets.Button):
    def __init__(self, track_path: str, display_text: str) -> None:
        self._track_path = track_path
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
                        label=display_text,
                        ellipsize="end",
                        max_width_chars=60,
                        css_classes=["music-track-label"],
                    ),
                ]
            ),
        )

    def play(self) -> None:
        window_manager.close_window("ignis_MUSIC_LAUNCHER")
        escaped_track = shlex.quote(self._track_path)
        # mpc next fails when stopped; insert appends to the queue end in that
        # state, so fall back to playing the last queue position
        command = (
            f'mpc insert {escaped_track} && '
            '{ mpc next || mpc play "$(mpc playlist | wc -l)"; } >/dev/null 2>&1 && '
            f'notify-send "Playing {escaped_track}"'
        )
        asyncio.create_task(utils.exec_sh_async(command))


class MusicArtistItem(widgets.Button):
    def __init__(self, artist_name: str) -> None:
        self._artist_name = artist_name
        super().__init__(
            on_click=lambda x: self.play(),
            css_classes=["music-track"],
            child=widgets.Box(
                child=[
                    widgets.Icon(
                        icon_name="avatar-default-symbolic",
                        pixel_size=32,
                        style="margin-right: 0.75rem;",
                    ),
                    widgets.Label(
                        label=artist_name,
                        ellipsize="end",
                        max_width_chars=60,
                        css_classes=["music-track-label"],
                    ),
                ]
            ),
        )

    def play(self) -> None:
        window_manager.close_window("ignis_MUSIC_LAUNCHER")
        escaped = shlex.quote(self._artist_name)
        # findadd appends to the queue end regardless of state, so jump to the
        # first appended track instead of relying on mpc next
        command = (
            'pos=$(($(mpc playlist | wc -l) + 1)); '
            f'mpc findadd artist {escaped} && '
            'mpc play "$pos" >/dev/null && '
            f'notify-send "Playing artist {escaped}"'
        )
        asyncio.create_task(utils.exec_sh_async(command))


class MusicAlbumItem(widgets.Button):
    def __init__(self, album_name: str) -> None:
        self._album_name = album_name
        super().__init__(
            on_click=lambda x: self.play(),
            css_classes=["music-track"],
            child=widgets.Box(
                child=[
                    widgets.Icon(
                        icon_name="media-optical-symbolic",
                        pixel_size=32,
                        style="margin-right: 0.75rem;",
                    ),
                    widgets.Label(
                        label=album_name,
                        ellipsize="end",
                        max_width_chars=60,
                        css_classes=["music-track-label"],
                    ),
                ]
            ),
        )

    def play(self) -> None:
        window_manager.close_window("ignis_MUSIC_LAUNCHER")
        escaped = shlex.quote(self._album_name)
        command = f'mpc clear && mpc findadd album {escaped} && mpc play && notify-send "Playing album {escaped}"'
        asyncio.create_task(utils.exec_sh_async(command))


class MusicPlaylistItem(widgets.Button):
    def __init__(self, playlist_name: str) -> None:
        self._playlist_name = playlist_name
        super().__init__(
            on_click=lambda x: self.play(),
            css_classes=["music-track"],
            child=widgets.Box(
                child=[
                    widgets.Icon(
                        icon_name="view-list-symbolic",
                        pixel_size=32,
                        style="margin-right: 0.75rem;",
                    ),
                    widgets.Label(
                        label=playlist_name,
                        ellipsize="end",
                        max_width_chars=60,
                        css_classes=["music-track-label"],
                    ),
                ]
            ),
        )

    def play(self) -> None:
        window_manager.close_window("ignis_MUSIC_LAUNCHER")
        escaped = shlex.quote(self._playlist_name)
        command = f'mpc clear && mpc load {escaped} && mpc play && notify-send "Playing playlist {escaped}"'
        asyncio.create_task(utils.exec_sh_async(command))


class MusicLauncher(widgets.Window):
    def __init__(self):
        self._mode_index = 0
        self._data = {mode: [] for mode in SEARCH_MODES}

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

        key_ctrl = Gtk.EventControllerKey.new()
        key_ctrl.connect("key-pressed", self.__on_key_pressed)
        self._entry.add_controller(key_ctrl)

        self._mode_labels = []
        for i, mode in enumerate(SEARCH_MODES):
            label = widgets.Label(
                label=mode,
                css_classes=["music-mode-active" if i == 0 else "music-mode"],
            )
            self._mode_labels.append(label)

        separator_children = []
        for i, label in enumerate(self._mode_labels):
            separator_children.append(label)
            if i < len(self._mode_labels) - 1:
                separator_children.append(
                    widgets.Label(
                        label="·",
                        css_classes=["music-mode-separator"],
                        style="margin: 0 0.4rem;",
                    )
                )

        self._mode_bar = widgets.Box(
            css_classes=["music-mode-bar"],
            halign="center",
            child=separator_children,
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
                self._mode_bar,
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

        self.__load_all_data()

    def __load_all_data(self) -> None:
        result = utils.exec_sh("mpc listall")
        if result.stdout:
            self._data["All Songs"] = [
                t.strip() for t in result.stdout.split("\n") if t.strip()
            ]

        result = utils.exec_sh("mpc list artist")
        if result.stdout:
            self._data["Artists"] = [
                a.strip() for a in result.stdout.split("\n") if a.strip()
            ]

        result = utils.exec_sh("mpc list album")
        if result.stdout:
            self._data["Albums"] = [
                a.strip() for a in result.stdout.split("\n") if a.strip()
            ]

        result = utils.exec_sh("mpc lsplaylists")
        if result.stdout:
            self._data["Playlists"] = [
                p.strip() for p in result.stdout.split("\n") if p.strip()
            ]

    def __on_open(self, *args) -> None:
        if not self.visible:
            return

        self._entry.text = ""
        self._mode_index = 0
        self.__update_mode_labels()
        self._entry.grab_focus()
        self.__load_all_data()

    def __on_key_pressed(self, controller, keyval, keycode, state) -> bool:
        if keyval == Gdk.KEY_Tab:
            self._mode_index = (self._mode_index + 1) % len(SEARCH_MODES)
            self.__update_mode_labels()
            self.__search()
            return True
        if keyval == Gdk.KEY_ISO_Left_Tab:
            self._mode_index = (self._mode_index - 1) % len(SEARCH_MODES)
            self.__update_mode_labels()
            self.__search()
            return True
        return False

    def __update_mode_labels(self) -> None:
        for i, label in enumerate(self._mode_labels):
            label.css_classes = [
                "music-mode-active" if i == self._mode_index else "music-mode"
            ]

    def __on_accept(self, *args) -> None:
        if len(self._track_list.child) > 0:
            self._track_list.child[0].play()

    def __search(self, *args) -> None:
        query = self._entry.text.lower()
        mode = SEARCH_MODES[self._mode_index]

        if query == "":
            self._entry.grab_focus()
            self._track_list.visible = False
            return

        items = self._data.get(mode, [])

        if mode == "All Songs":
            filtered = [
                t for t in items
                if query in t.lower() or query in _format_track_display(t).lower()
            ]
            if filtered:
                self._track_list.child = [
                    MusicTrackItem(t, _format_track_display(t))
                    for t in filtered[:20]
                ]
            else:
                self._track_list.child = [self.__no_results_label()]
        elif mode == "Artists":
            filtered = [a for a in items if query in a.lower()]
            if filtered:
                self._track_list.child = [
                    MusicArtistItem(a) for a in filtered[:20]
                ]
            else:
                self._track_list.child = [self.__no_results_label()]
        elif mode == "Albums":
            filtered = [a for a in items if query in a.lower()]
            if filtered:
                self._track_list.child = [
                    MusicAlbumItem(a) for a in filtered[:20]
                ]
            else:
                self._track_list.child = [self.__no_results_label()]
        elif mode == "Playlists":
            filtered = [p for p in items if query in p.lower()]
            if filtered:
                self._track_list.child = [
                    MusicPlaylistItem(p) for p in filtered[:20]
                ]
            else:
                self._track_list.child = [self.__no_results_label()]

        self._track_list.visible = True

    def __no_results_label(self) -> widgets.Label:
        return widgets.Label(
            label="No results found",
            css_classes=["music-no-results"],
            style="padding: 1rem;",
        )
