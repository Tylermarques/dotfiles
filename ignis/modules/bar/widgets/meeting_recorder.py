from ignis import widgets
from services.meeting_notes import meeting_notes_service


class MeetingRecorderIndicator(widgets.Icon):
    def __init__(self) -> None:
        super().__init__(
            image="media-record-symbolic",
            pixel_size=14,
            css_classes=["unset", "meeting-recorder-indicator"],
            visible=meeting_notes_service.is_recording.bind("value"),
            tooltip_text="Meeting is being recorded",
        )
