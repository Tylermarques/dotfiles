import subprocess
import asyncio
from ignis import widgets
from ignis.variable import Variable
from gi.repository import GObject  # type: ignore
from typing import Callable


# Standalone QSButton implementation to avoid import issues
class VoiceToTextQSButton(widgets.Button):
    def __init__(
        self,
        label: str,
        icon_name: str,
        on_activate: Callable | None = None,
        on_deactivate: Callable | None = None,
        **kwargs,
    ):
        self.on_activate = on_activate
        self.on_deactivate = on_deactivate
        self._active = False
        
        super().__init__(
            child=widgets.Box(
                child=[
                    widgets.Icon(image=icon_name),
                    widgets.Label(label=label, css_classes=["qs-button-label"]),
                ]
            ),
            on_click=self.__callback,
            css_classes=["qs-button", "unset"],
            hexpand=True,
            **kwargs,
        )

    def __callback(self, *args) -> None:
        if self.active:
            if self.on_deactivate:
                self.on_deactivate(self)
        else:
            if self.on_activate:
                self.on_activate(self)

    @GObject.Property
    def active(self) -> bool:
        return self._active

    @active.setter
    def active(self, value: bool) -> None:
        self._active = value
        if value:
            self.add_css_class("active")
        else:
            self.remove_css_class("active")


class VoiceToTextService:
    """Simple service to track voice-to-text recording state."""
    
    def __init__(self):
        self.is_recording = Variable(False)
        self.process = None
    
    async def start_recording(self):
        """Start voice-to-text recording."""
        if self.process and self.process.poll() is None:
            return  # Already running
        
        self.is_recording.set_value(True)
        
        try:
            # Start the voice-to-text script
            self.process = subprocess.Popen(
                ["uv", "run", "/home/tyler/dotfiles/scripts/voice_to_text.py"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd="/home/tyler/dotfiles/scripts"
            )
            
            # Wait for process to complete
            await asyncio.create_task(self._wait_for_process())
            
        except Exception as e:
            print(f"Error starting voice-to-text: {e}")
        finally:
            self.is_recording.set_value(False)
            self.process = None
    
    async def _wait_for_process(self):
        """Wait for the voice-to-text process to complete."""
        if not self.process:
            return
        
        # Run in executor to avoid blocking
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.process.wait)
    
    def stop_recording(self):
        """Stop voice-to-text recording."""
        if self.process and self.process.poll() is None:
            self.process.terminate()
        self.is_recording.set_value(False)
        self.process = None


# Global instance
voice_to_text_service = VoiceToTextService()


class VoiceToTextButton(VoiceToTextQSButton):
    def __init__(self):
        super().__init__(
            label="Voice to Text",
            icon_name="microphone-disabled-symbolic",
            on_activate=lambda x: asyncio.create_task(self._start_recording()),
            on_deactivate=lambda x: self._stop_recording(),
        )
        
        # Add menu property for compatibility with QuickSettings layout code
        self.menu = None
        
        # Bind the active state to the service
        voice_to_text_service.is_recording.connect("notify::value", self._on_recording_changed)
        
        # Update icon based on recording state
        voice_to_text_service.is_recording.connect("notify::value", self._update_icon)
    
    def _on_recording_changed(self, *args):
        """Update button active state when recording changes."""
        self.active = voice_to_text_service.is_recording.value
    
    def _update_icon(self, *args):
        """Update icon based on recording state."""
        icon_widget = self.child.child[0]  # First child is the icon
        if voice_to_text_service.is_recording.value:
            icon_widget.image = "microphone-sensitivity-high-symbolic"
        else:
            icon_widget.image = "microphone-disabled-symbolic"
    
    async def _start_recording(self):
        """Start voice-to-text recording."""
        await voice_to_text_service.start_recording()
    
    def _stop_recording(self):
        """Stop voice-to-text recording."""
        voice_to_text_service.stop_recording()