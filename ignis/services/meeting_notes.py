"""Client for the meeting-notes D-Bus service.

Proxies org.meetingnotes.Service on the session bus and exposes the
IsRecording property as an Ignis Variable so widgets can bind to it.
"""

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
    <signal name="RecordingStateChanged">
      <arg type="b"/>
    </signal>
    <signal name="RecordingDegraded">
      <arg type="s"/>
    </signal>
  </interface>
</node>"""


class MeetingNotesService:
    def __init__(self) -> None:
        self.is_recording = Variable(False)
        self._proxy: Gio.DBusProxy | None = None

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

    def _on_proxy_ready(self, _source, result) -> None:
        try:
            self._proxy = Gio.DBusProxy.new_for_bus_finish(result)
        except GLib.Error as exc:
            print(f"meeting_notes: failed to create D-Bus proxy: {exc}")
            return

        self._proxy.connect("g-properties-changed", self._refresh)
        self._proxy.connect("notify::g-name-owner", self._refresh)
        self._refresh()

    def _refresh(self, *_args) -> None:
        if self._proxy is None or self._proxy.get_name_owner() is None:
            self.is_recording.value = False
            return

        cached = self._proxy.get_cached_property("IsRecording")
        self.is_recording.value = bool(cached.unpack()) if cached is not None else False


meeting_notes_service = MeetingNotesService()
