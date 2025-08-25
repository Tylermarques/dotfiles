#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "RealtimeSTT",
# ]
# ///

import sys
import os
import signal
from RealtimeSTT import AudioToTextRecorder

PID_FILE = "/tmp/dictate.pid"


def start_recording():
    """Start real-time speech recording and save PID"""
    # Save the process PID so we can stop it later
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    # Initialize recorder with optimized settings for dictation
    recorder = AudioToTextRecorder(
        model="large-v3-turbo",  # Fast, high-quality model
        language="en",
        enable_realtime_transcription=False,  # We want final result only
        use_microphone=True,
        silero_sensitivity=0.4,  # Voice activity detection sensitivity
        webrtc_sensitivity=2,
        post_speech_silence_duration=0.7,  # Stop recording after this much silence
        min_length_of_recording=0.1,
        min_gap_between_recordings=0,
        wake_words_sensitivity=0.6,
        pre_recording_buffer_duration=1.0,
    )

    # Start recording and wait for speech
    print("Recording started. Speak now...")
    text = recorder.text()

    # Clean up whitespace and output the transcribed text
    if text:
        cleaned_text = text.strip()
        if cleaned_text:
            print(cleaned_text, end="")

    # Clean up PID file
    if os.path.exists(PID_FILE):
        os.remove(PID_FILE)


def stop_recording():
    """Stop the recording process if it's running"""
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
            os.remove(PID_FILE)
        except (ProcessLookupError, ValueError, FileNotFoundError):
            # Process already stopped or PID file corrupted
            if os.path.exists(PID_FILE):
                os.remove(PID_FILE)


def main():
    if len(sys.argv) != 2:
        print("Usage: dictate.py [start|stop]", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    if command == "start":
        start_recording()
    elif command == "stop":
        stop_recording()
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

