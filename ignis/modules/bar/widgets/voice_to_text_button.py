import subprocess
import asyncio
import sys
import os
import importlib.util
from ignis import widgets
from ignis.variable import Variable


# Import voice-to-text service - using direct path to avoid relative import issues
try:
    voice_to_text_path = os.path.expanduser("~/.config/ignis/modules/control_center/widgets/quick_settings/voice_to_text.py")
    spec = importlib.util.spec_from_file_location("voice_to_text", voice_to_text_path)
    voice_to_text_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(voice_to_text_module)
    voice_to_text_service = voice_to_text_module.voice_to_text_service
except Exception as e:
    print(f"Warning: Could not import voice_to_text_service: {e}")
    # Create a dummy service to prevent errors
    class DummyService:
        def __init__(self):
            self.is_recording = Variable(False)
        async def start_recording(self):
            pass
        def stop_recording(self):
            pass
    voice_to_text_service = DummyService()


class VoiceToTextBarButton(widgets.Button):
    def __init__(self):
        super().__init__(
            child=widgets.Icon(
                image=voice_to_text_service.is_recording.bind(
                    "value",
                    lambda recording: "microphone-sensitivity-high-symbolic" 
                    if recording else "microphone-disabled-symbolic"
                ),
                pixel_size=20,
            ),
            css_classes=voice_to_text_service.is_recording.bind(
                "value",
                lambda recording: ["voice-to-text-button", "active"] 
                if recording else ["voice-to-text-button"]
            ),
            tooltip_text=voice_to_text_service.is_recording.bind(
                "value",
                lambda recording: "Recording voice... (click to stop)" 
                if recording else "Click to start voice-to-text"
            ),
            on_click=self._on_click,
        )
        
        # Connect to recording state changes
        voice_to_text_service.is_recording.connect("notify::value", self._on_recording_changed)
    
    def _on_click(self, *args):
        """Handle button click - start or stop recording."""
        if voice_to_text_service.is_recording.value:
            # Currently recording, stop it
            voice_to_text_service.stop_recording()
        else:
            # Not recording, start it
            asyncio.create_task(voice_to_text_service.start_recording())
    
    def _on_recording_changed(self, *args):
        """Update button state when recording changes."""
        # The CSS classes and icon are already bound to the recording state
        # This is just here for any additional state management if needed
        pass