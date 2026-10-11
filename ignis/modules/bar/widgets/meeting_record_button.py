"""Bar button controlling meeting-notes manual window capture.

States (css classes on .meeting-record-button):
  idle              dim record icon; left-click opens the slurp window picker
  .picking          pulsing; left-click cancels the picker
  .active           red + elapsed timer; left-click stops (manual recordings)
  .active.auto      provider-started recording; left-click opens the menu instead
                    (force stop lives there, behind a second click)
  .error            brief flash when a command fails
  .unavailable      capture service not running

Right-click always opens the menu: record focused window, pick any open
window from a list (works across workspaces, no slurp), force stop, open UI.
"""

from __future__ import annotations

import asyncio

from ignis import utils, widgets
from ignis.menu_model import IgnisMenuItem, IgnisMenuModel, IgnisMenuSeparator
from ignis.services.hyprland import HyprlandService

from services.meeting_notes import meeting_notes_service as mn

hyprland = HyprlandService.get_default()

WEBUI_URL = "http://127.0.0.1:8636"
MAX_MENU_WINDOWS = 12
MAX_MENU_LABEL = 48


def _shorten(text: str, limit: int = MAX_MENU_LABEL) -> str:
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


class MeetingRecordButton(widgets.Button):
    __gtype_name__ = "MeetingRecordButton"

    def __init__(self) -> None:
        self._icon = widgets.Icon(image="media-record-symbolic", pixel_size=18)
        self._elapsed = widgets.Label(label="", css_classes=["elapsed"], visible=False)
        self._menu = widgets.PopoverMenu()

        super().__init__(
            child=widgets.Box(child=[self._icon, self._elapsed, self._menu], spacing=0),
            css_classes=["meeting-record-button", "unset"],
            on_click=self._on_click,
            on_right_click=lambda *_: self._popup_menu(),
        )

        for var in (
            mn.available, mn.is_recording, mn.picker_active,
            mn.is_manual, mn.title, mn.last_error,
        ):
            var.connect("notify::value", self._sync)

        self._poll = utils.Poll(1000, self._tick)
        self._sync()

    # ------------------------------------------------------------------
    # State → presentation
    # ------------------------------------------------------------------

    def _tick(self, *_args) -> None:
        text = mn.elapsed_text()
        self._elapsed.label = text
        self._elapsed.visible = bool(text)

    def _sync(self, *_args) -> None:
        classes = ["meeting-record-button", "unset"]
        if not mn.available.value:
            classes.append("unavailable")
        if mn.picker_active.value:
            classes.append("picking")
        if mn.is_recording.value:
            classes.append("active")
            if not mn.is_manual.value:
                classes.append("auto")
        if mn.last_error.value:
            classes.append("error")
        self.css_classes = classes
        self.tooltip_text = self._tooltip()
        self._tick()

    def _tooltip(self) -> str:
        if mn.last_error.value:
            return mn.last_error.value
        if not mn.available.value:
            return "meeting-notes service is not running"
        if mn.picker_active.value:
            return "Picking… click a window to record it (Esc or click here to cancel)"
        if mn.is_recording.value:
            title = mn.title.value or "meeting"
            if mn.is_manual.value:
                return f"Recording {title} · click to stop"
            return f"Auto-recording {title} · ends with the meeting (right-click to force stop)"
        return "Record a window (click) · more options (right-click)"

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def _on_click(self, *_args) -> None:
        if not mn.available.value:
            return
        if mn.picker_active.value:
            mn.cancel_pick()
        elif mn.is_recording.value:
            if mn.is_manual.value:
                mn.stop()
            else:
                self._popup_menu()
        else:
            mn.pick_and_start()

    def _popup_menu(self) -> None:
        self._menu.model = self._build_menu()
        self._menu.popup()

    def _build_menu(self) -> IgnisMenuModel:
        recording = mn.is_recording.value
        items: list = []

        if mn.picker_active.value:
            items.append(IgnisMenuItem(label="Cancel picking", on_activate=lambda *_: mn.cancel_pick()))
        elif not recording:
            items.append(IgnisMenuItem(label="Pick a window on screen…", on_activate=lambda *_: mn.pick_and_start()))
            items.append(IgnisMenuItem(label="Record focused window", on_activate=lambda *_: mn.start("")))

        if not recording and hyprland.is_available:
            windows = [w for w in hyprland.windows if w.mapped and not w.hidden and w.title]
            windows.sort(key=lambda w: (w.workspace_id, w.class_name.lower()))
            if windows:
                items.append(IgnisMenuSeparator())
                for w in windows[:MAX_MENU_WINDOWS]:
                    label = _shorten(f"[{w.workspace_id}] {w.class_name} — {w.title}")
                    items.append(
                        IgnisMenuItem(
                            label=label,
                            on_activate=lambda *_, addr=w.address: mn.start(addr),
                        )
                    )

        items.append(IgnisMenuSeparator())
        items.append(
            IgnisMenuItem(
                label="Stop recording" if mn.is_manual.value else "Stop recording (force)",
                enabled=recording,
                on_activate=lambda *_: mn.stop(force=True),
            )
        )
        items.append(
            IgnisMenuItem(
                label="Open Meeting Notes",
                on_activate=lambda *_: asyncio.create_task(utils.exec_sh_async(f"xdg-open {WEBUI_URL}")),
            )
        )
        return IgnisMenuModel(*items)
