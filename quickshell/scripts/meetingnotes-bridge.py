#!/usr/bin/env python3
"""Bridge between Quickshell and the org.meetingnotes.Service D-Bus service.

Quickshell has no generic D-Bus client, so this process does the talking:

  stdout  one JSON object per line
            {"type": "state", "available", "isRecording", "pickerActive",
             "isManual", "provider", "title", "meetingId", "startMs"}
            {"type": "error", "message": "..."}
  stdin   one JSON object per line
            {"call": "StopRecording", "args": [true]}

Everything is asynchronous on a GLib main loop; the bridge exits when stdin
closes (i.e. when Quickshell stops or reloads it).
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone

from gi.repository import Gio, GLib

BUS_NAME = "org.meetingnotes.Service"
OBJECT_PATH = "/org/meetingnotes/Service"
INTERFACE = "org.meetingnotes.Service"

INTERFACE_XML = """<node>
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
    <signal name="RecordingStateChanged"><arg type="b"/></signal>
    <signal name="RecordingDegraded"><arg type="s"/></signal>
    <signal name="CommandFailed"><arg type="s"/></signal>
  </interface>
</node>"""

# Input signature for each callable method; anything else is rejected.
METHODS = {
    "PickAndStartRecording": None,
    "CancelPick": None,
    "StartManualRecording": "(s)",
    "StopRecording": "(b)",
    "ToggleManualRecording": None,
}

# "GDBus.Error:org.meetingnotes.Error.AlreadyRecording: message" -> "message"
GDBUS_ERROR_RE = re.compile(r"^GDBus\.Error:[\w.]+:\s*")
BROWSER_SUFFIX_RE = re.compile(r"\s*[—-]\s*(Mozilla Firefox|Chromium|Google Chrome|Brave)$")


def display_title(raw: str) -> str:
    """Trim browser suffixes / Meet prefix from a raw window title."""
    title = BROWSER_SUFFIX_RE.sub("", (raw or "").strip())
    if title.startswith("Meet - "):
        title = title[len("Meet - "):]
    return title.strip() or "Meeting"


def emit(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


class Bridge:
    def __init__(self, loop: GLib.MainLoop) -> None:
        self.loop = loop
        self.proxy: Gio.DBusProxy | None = None
        self.last_state: dict | None = None

        info = Gio.DBusNodeInfo.new_for_xml(INTERFACE_XML).interfaces[0]
        Gio.DBusProxy.new_for_bus(
            Gio.BusType.SESSION,
            Gio.DBusProxyFlags.DO_NOT_AUTO_START,
            info,
            BUS_NAME,
            OBJECT_PATH,
            INTERFACE,
            None,
            self.on_proxy_ready,
        )

        stdin = GLib.IOChannel.unix_new(sys.stdin.fileno())
        GLib.io_add_watch(stdin, GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN | GLib.IOCondition.HUP, self.on_stdin)

    def on_proxy_ready(self, _source, result) -> None:
        try:
            self.proxy = Gio.DBusProxy.new_for_bus_finish(result)
        except GLib.Error as exc:
            emit({"type": "error", "message": f"D-Bus proxy failed: {exc.message}"})
            self.publish()
            return
        self.proxy.connect("g-properties-changed", self.publish)
        self.proxy.connect("notify::g-name-owner", self.publish)
        self.proxy.connect("g-signal", self.on_signal)
        self.publish()

    def cached(self, name: str, default):
        value = self.proxy.get_cached_property(name) if self.proxy else None
        return value.unpack() if value is not None else default

    def publish(self, *_args) -> None:
        state = {"type": "state", "available": False, "isRecording": False,
                 "pickerActive": False, "isManual": False, "provider": "",
                 "title": "", "meetingId": 0, "startMs": 0}

        if self.proxy is not None and self.proxy.get_name_owner() is not None:
            meeting = self.cached("CurrentMeeting", {}) or {}
            state.update(
                available=True,
                isRecording=bool(self.cached("IsRecording", False)),
                pickerActive=bool(self.cached("PickerActive", False)),
                isManual=bool(meeting.get("manual", False)),
                provider=str(meeting.get("provider", "")),
                title=display_title(str(meeting.get("window_title", ""))),
            )
            try:
                state["meetingId"] = int(meeting.get("meeting_id", 0) or 0)
            except (TypeError, ValueError):
                pass
            start = meeting.get("start_time")
            if start:
                try:
                    parsed = datetime.fromisoformat(str(start))
                    if parsed.tzinfo is None:
                        parsed = parsed.replace(tzinfo=timezone.utc)
                    state["startMs"] = int(parsed.timestamp() * 1000)
                except ValueError:
                    pass

        if state != self.last_state:
            self.last_state = state
            emit(state)

    def on_signal(self, _proxy, _sender, name: str, params: GLib.Variant) -> None:
        if name == "CommandFailed":
            emit({"type": "error", "message": str(params.unpack()[0])})
        elif name == "RecordingDegraded":
            emit({"type": "error", "message": f"Degraded: {params.unpack()[0]}"})

    def on_stdin(self, channel: GLib.IOChannel, condition: GLib.IOCondition) -> bool:
        if condition & GLib.IOCondition.HUP and not condition & GLib.IOCondition.IN:
            self.loop.quit()
            return False
        line = channel.readline()
        if not line:
            self.loop.quit()
            return False
        try:
            request = json.loads(line)
            self.call(str(request["call"]), list(request.get("args", [])))
        except (ValueError, KeyError, TypeError) as exc:
            emit({"type": "error", "message": f"bad request: {exc}"})
        return True

    def call(self, method: str, args: list) -> None:
        if method not in METHODS:
            emit({"type": "error", "message": f"unknown method {method}"})
            return
        if self.proxy is None or self.proxy.get_name_owner() is None:
            emit({"type": "error", "message": "meeting-notes service is not running"})
            return

        signature = METHODS[method]
        params = GLib.Variant(signature, tuple(args)) if signature else None

        def done(proxy: Gio.DBusProxy, result) -> None:
            try:
                proxy.call_finish(result)
            except GLib.Error as exc:
                emit({"type": "error", "message": GDBUS_ERROR_RE.sub("", exc.message)})

        self.proxy.call(method, params, Gio.DBusCallFlags.NONE, 10_000, None, done)


def main() -> None:
    loop = GLib.MainLoop()
    Bridge(loop)
    loop.run()


if __name__ == "__main__":
    main()
