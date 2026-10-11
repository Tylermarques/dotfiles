"""Client for the meeting-notes D-Bus service.

Proxies org.meetingnotes.Service on the session bus and exposes its state as
Ignis Variables so widgets can bind to it, plus non-blocking method wrappers
for manual window capture (pick / start / stop / cancel).

All calls are asynchronous: the service's PickAndStartRecording returns
immediately and reports the outcome via the IsRecording / CurrentMeeting /
PickerActive properties and the CommandFailed signal, so nothing here ever
blocks the GTK main loop.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from gi.repository import Gio, GLib
from ignis import utils
from ignis.variable import Variable


MEETING_NOTES_BUS_NAME = "org.meetingnotes.Service"
MEETING_NOTES_OBJECT_PATH = "/org/meetingnotes/Service"
MEETING_NOTES_INTERFACE = "org.meetingnotes.Service"

_INTERFACE_XML = """<node>
  <interface name="org.meetingnotes.Service">
    <property name="IsRecording" type="b" access="read"/>
    <property name="CurrentMeeting" type="a{sv}" access="read"/>
    <property name="PickerActive" type="b" access="read"/>
    <method name="StartManualRecording">
      <arg direction="in" type="s" name="window_address"/>
      <arg direction="out" type="i" name="meeting_id"/>
    </method>
    <method name="PickAndStartRecording"/>
    <method name="CancelPick"/>
    <method name="StopRecording">
      <arg direction="in" type="b" name="force"/>
      <arg direction="out" type="b" name="stopped"/>
    </method>
    <method name="ToggleManualRecording">
      <arg direction="out" type="s" name="result"/>
    </method>
    <signal name="RecordingStateChanged">
      <arg type="b"/>
    </signal>
    <signal name="RecordingDegraded">
      <arg type="s"/>
    </signal>
    <signal name="CommandFailed">
      <arg type="s"/>
    </signal>
  </interface>
</node>"""

_ERROR_CLEARS_AFTER_MS = 4000
# "GDBus.Error:org.meetingnotes.Error.AlreadyRecording: message" -> "message"
_GDBUS_ERROR_RE = re.compile(r"^GDBus\.Error:[\w.]+:\s*")
_BROWSER_SUFFIX_RE = re.compile(r"\s*[—-]\s*(Mozilla Firefox|Chromium|Google Chrome|Brave)$")


def display_title(raw: str) -> str:
    """Trim browser suffixes / Meet prefix from a raw window title."""
    title = _BROWSER_SUFFIX_RE.sub("", (raw or "").strip())
    if title.startswith("Meet - "):
        title = title[len("Meet - "):]
    return title.strip() or "Meeting"


class MeetingNotesService:
    def __init__(self) -> None:
        # Bindable state
        self.available = Variable(False)       # service owns its bus name
        self.is_recording = Variable(False)
        self.picker_active = Variable(False)
        self.is_manual = Variable(False)
        self.title = Variable("")
        self.provider = Variable("")
        self.meeting_id = Variable(0)
        self.start_time = Variable(None)       # datetime | None (UTC)
        self.last_error = Variable("")         # auto-clears after a few seconds

        self._proxy: Gio.DBusProxy | None = None
        self._error_timeout: utils.Timeout | None = None

        info = utils.load_interface_xml(xml=_INTERFACE_XML)
        Gio.DBusProxy.new_for_bus(
            Gio.BusType.SESSION,
            Gio.DBusProxyFlags.DO_NOT_AUTO_START,
            info,
            MEETING_NOTES_BUS_NAME,
            MEETING_NOTES_OBJECT_PATH,
            MEETING_NOTES_INTERFACE,
            None,
            self._on_proxy_ready,
        )

    # ------------------------------------------------------------------
    # Proxy lifecycle / state sync
    # ------------------------------------------------------------------

    def _on_proxy_ready(self, _source, result) -> None:
        try:
            self._proxy = Gio.DBusProxy.new_for_bus_finish(result)
        except GLib.Error as exc:
            print(f"meeting_notes: failed to create D-Bus proxy: {exc}")
            return

        self._proxy.connect("g-properties-changed", self._refresh)
        self._proxy.connect("notify::g-name-owner", self._refresh)
        self._proxy.connect("g-signal", self._on_signal)
        self._refresh()

    def _cached(self, name: str, default):
        if self._proxy is None:
            return default
        value = self._proxy.get_cached_property(name)
        return value.unpack() if value is not None else default

    def _refresh(self, *_args) -> None:
        if self._proxy is None or self._proxy.get_name_owner() is None:
            self.available.value = False
            self.is_recording.value = False
            self.picker_active.value = False
            self.is_manual.value = False
            self.title.value = ""
            self.provider.value = ""
            self.meeting_id.value = 0
            self.start_time.value = None
            return

        self.available.value = True
        self.is_recording.value = bool(self._cached("IsRecording", False))
        self.picker_active.value = bool(self._cached("PickerActive", False))

        meeting = self._cached("CurrentMeeting", {}) or {}
        self.is_manual.value = bool(meeting.get("manual", False))
        self.provider.value = str(meeting.get("provider", ""))
        self.title.value = display_title(str(meeting.get("window_title", "")))
        try:
            self.meeting_id.value = int(meeting.get("meeting_id", 0) or 0)
        except (TypeError, ValueError):
            self.meeting_id.value = 0

        start = meeting.get("start_time")
        parsed: datetime | None = None
        if start:
            try:
                parsed = datetime.fromisoformat(str(start))
                if parsed.tzinfo is None:
                    parsed = parsed.replace(tzinfo=timezone.utc)
            except ValueError:
                parsed = None
        self.start_time.value = parsed

    def _on_signal(self, _proxy, _sender, signal_name: str, params: GLib.Variant) -> None:
        if signal_name == "CommandFailed":
            (reason,) = params.unpack()
            self._set_error(str(reason))
        elif signal_name == "RecordingDegraded":
            # Advisory only; surface briefly.
            (reason,) = params.unpack()
            self._set_error(f"Degraded: {reason}")

    def _set_error(self, message: str) -> None:
        self.last_error.value = message
        if self._error_timeout is not None:
            self._error_timeout.cancel()
        self._error_timeout = utils.Timeout(_ERROR_CLEARS_AFTER_MS, self._clear_error)

    def _clear_error(self, *_args) -> bool:
        self.last_error.value = ""
        self._error_timeout = None
        return False  # GLib: do not repeat

    # ------------------------------------------------------------------
    # Method wrappers (all non-blocking)
    # ------------------------------------------------------------------

    def _call(self, method: str, params: GLib.Variant | None = None, timeout_ms: int = 10_000) -> None:
        if self._proxy is None or self._proxy.get_name_owner() is None:
            self._set_error("meeting-notes service is not running")
            return

        def _done(proxy: Gio.DBusProxy, result) -> None:
            try:
                proxy.call_finish(result)
            except GLib.Error as exc:
                self._set_error(_GDBUS_ERROR_RE.sub("", exc.message))

        self._proxy.call(method, params, Gio.DBusCallFlags.NONE, timeout_ms, None, _done)

    def pick_and_start(self) -> None:
        """Open the slurp overlay on the desktop; outcome arrives via properties."""
        self._call("PickAndStartRecording")

    def cancel_pick(self) -> None:
        self._call("CancelPick")

    def start(self, window_address: str = "") -> None:
        """Record a specific window (empty address = currently focused window)."""
        self._call("StartManualRecording", GLib.Variant("(s)", (window_address,)))

    def stop(self, force: bool = False) -> None:
        """Stop the active recording. Without force only manual recordings stop."""
        self._call("StopRecording", GLib.Variant("(b)", (force,)))

    def toggle(self) -> None:
        self._call("ToggleManualRecording")

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def elapsed_text(self) -> str:
        """mm:ss (or h:mm:ss) since the current meeting started; '' when idle."""
        start = self.start_time.value
        if not self.is_recording.value or start is None:
            return ""
        seconds = max(0, int((datetime.now(timezone.utc) - start).total_seconds()))
        h, rem = divmod(seconds, 3600)
        m, s = divmod(rem, 60)
        return f"{h}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


meeting_notes_service = MeetingNotesService()
