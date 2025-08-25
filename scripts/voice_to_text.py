#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "sounddevice>=0.5.2",
#     "soundfile>=0.13.1",
#     "requests>=2.32.0",
#     "numpy>=2.0.0",
# ]
# ///

import asyncio
import base64
import io
import logging
import subprocess
import sys
import time
from typing import Optional
from datetime import datetime

import numpy as np
import sounddevice as sd
import soundfile as sf
import requests

# Configuration
SAMPLE_RATE = 16000
SAMPLE_WIDTH = 2
CHANNELS = 1
DTYPE = "int16"
CHUNK_SIZE = 1024
SPEACHES_BASE_URL = "http://localhost:8000"
MODEL = "Systran/faster-distil-whisper-large-v3"

# VAD Configuration
SILENCE_THRESHOLD = 0.01  # RMS threshold for silence detection
SILENCE_DURATION = 2.0    # Seconds of silence before stopping
MIN_RECORDING_DURATION = 0.5  # Minimum recording duration in seconds

# Logging Configuration
LOG_FILE = "/tmp/voice_to_text.log"

# Set up logging to both console and file
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class VoiceToText:
    def __init__(self, base_url: str = SPEACHES_BASE_URL, model: str = MODEL):
        self.base_url = base_url
        self.model = model
        self.recording = False
        self.audio_buffer = []

    def transcribe_audio(self, audio_data: bytes) -> Optional[str]:
        """Send audio data to speaches.ai for transcription."""
        try:
            # Create a temporary file-like object for the audio data
            files = {"file": ("audio.wav", audio_data, "audio/wav")}
            data = {"model": self.model, "response_format": "json"}

            response = requests.post(
                f"{self.base_url}/v1/audio/transcriptions",
                files=files,
                data=data,
                timeout=10,
            )

            if response.status_code == 200:
                result = response.json()
                return result.get("text", "").strip()
            else:
                logger.error(
                    f"Transcription failed: {response.status_code} - {response.text}"
                )
                return None

        except Exception as e:
            logger.error(f"Error during transcription: {e}")
            return None

    def type_text(self, text: str):
        """Use wtype to type the transcribed text."""
        try:
            subprocess.run(["wtype", text], check=True)
            logger.info(f"Typed: {text}")
        except subprocess.CalledProcessError as e:
            logger.error(f"Error typing text: {e}")
        except FileNotFoundError:
            logger.error("wtype not found. Please install it: sudo apt install wtype")

    def calculate_rms(self, audio_data: np.ndarray) -> float:
        """Calculate RMS (Root Mean Square) of audio data for voice activity detection."""
        return np.sqrt(np.mean(audio_data**2))

    def record_with_vad(self) -> bytes:
        """Record audio with voice activity detection."""
        logger.info("Listening... Start speaking!")
        
        audio_buffer = []
        silence_start = None
        recording_started = False
        start_time = time.time()
        
        logger.info(f"Audio settings: {SAMPLE_RATE}Hz, {CHANNELS} channel(s), {DTYPE}")
        logger.info(f"VAD settings: threshold={SILENCE_THRESHOLD}, silence_duration={SILENCE_DURATION}s")
        
        stream = sd.InputStream(
            channels=CHANNELS,
            samplerate=SAMPLE_RATE,
            dtype=DTYPE,
            blocksize=CHUNK_SIZE
        )
        
        try:
            stream.start()
            
            while True:
                # Read audio chunk
                audio_chunk, overflowed = stream.read(CHUNK_SIZE)
                if overflowed:
                    logger.warning("Audio buffer overflowed")
                
                # Convert to float for RMS calculation
                audio_float = audio_chunk.astype(np.float32) / 32768.0
                rms = self.calculate_rms(audio_float)
                
                # Voice activity detection
                if rms > SILENCE_THRESHOLD:
                    # Voice detected
                    if not recording_started:
                        logger.info("Voice detected, recording started...")
                        recording_started = True
                        start_time = time.time()
                    
                    audio_buffer.append(audio_chunk)
                    silence_start = None
                    
                else:
                    # Silence detected
                    if recording_started:
                        if silence_start is None:
                            logger.debug("Silence detected, starting silence timer...")
                            silence_start = time.time()
                        
                        # Add silence to buffer (up to silence duration)
                        audio_buffer.append(audio_chunk)
                        
                        # Check if we've had enough silence
                        silence_duration = time.time() - silence_start
                        recording_duration = time.time() - start_time
                        
                        if (silence_duration >= SILENCE_DURATION and 
                            recording_duration >= MIN_RECORDING_DURATION):
                            logger.info(f"Silence duration ({silence_duration:.1f}s) reached threshold. Stopping recording...")
                            break
                
                # Safety timeout (60 seconds max)
                if time.time() - start_time > 60:
                    logger.warning("Recording timeout (60s) reached, stopping...")
                    break
        
        finally:
            stream.stop()
            stream.close()
        
        if not audio_buffer:
            logger.warning("No audio recorded")
            return b""
        
        # Combine all audio chunks
        combined_audio = np.concatenate(audio_buffer, axis=0)
        
        # Convert to WAV format
        wav_buffer = io.BytesIO()
        sf.write(wav_buffer, combined_audio, SAMPLE_RATE, format="WAV")
        
        duration = len(combined_audio) / SAMPLE_RATE
        logger.info(f"Recorded {duration:.2f} seconds of audio")
        
        return wav_buffer.getvalue()

    def listen_and_transcribe(self):
        """Record audio with VAD, transcribe, and type the result."""
        logger.info("=== Voice-to-Text Session Started ===")
        logger.info("Voice-to-Text with VAD started!")
        logger.info("Make sure the target text field is focused where you want the text to appear.")
        logger.info(f"Will stop recording after {SILENCE_DURATION} seconds of silence.")
        logger.info("Press Ctrl+C to abort")
        logger.info(f"Log file: {LOG_FILE}")

        try:
            # Record audio with voice activity detection
            logger.info("Starting voice activity detection...")
            audio_data = self.record_with_vad()

            if audio_data:
                logger.info("Audio recorded successfully, starting transcription...")
                text = self.transcribe_audio(audio_data)

                if text and len(text.strip()) > 0:
                    logger.info(f"Transcription successful: '{text}'")
                    self.type_text(text)
                    logger.info("Text has been typed successfully. Session complete.")
                else:
                    logger.warning("No speech detected or transcription failed")
            else:
                logger.warning("No audio was recorded")

        except KeyboardInterrupt:
            logger.info("Session aborted by user")
        except Exception as e:
            logger.error(f"Unexpected error occurred: {e}")
        finally:
            logger.info("=== Voice-to-Text Session Ended ===\n")


def main():
    """Entry point for the script."""
    if len(sys.argv) > 1:
        if sys.argv[1] in ["-h", "--help"]:
            print("Voice-to-Text Tool with Voice Activity Detection")
            print("Usage: uv run voice_to_text.py [base_url] [model]")
            print(f"Default base_url: {SPEACHES_BASE_URL}")
            print(f"Default model: {MODEL}")
            print(f"Log file: {LOG_FILE}")
            print("\nThis tool will:")
            print("1. Listen for voice activity")
            print("2. Record until you stop speaking (2 seconds of silence)")
            print("3. Send audio to speaches.ai for transcription")
            print("4. Type the transcribed text using wtype and exit")
            print("\nConfiguration:")
            print(f"- Silence threshold: {SILENCE_THRESHOLD}")
            print(f"- Silence duration: {SILENCE_DURATION}s")
            print(f"- Min recording: {MIN_RECORDING_DURATION}s")
            print("\nMake sure:")
            print("- speaches.ai is running on the specified URL")
            print("- wtype is installed (sudo apt install wtype)")
            print("- The target text field is focused")
            print(f"\nTo watch logs in real-time:")
            print(f"tail -f {LOG_FILE}")
            return

    # Parse command line arguments
    base_url = sys.argv[1] if len(sys.argv) > 1 else SPEACHES_BASE_URL
    model = sys.argv[2] if len(sys.argv) > 2 else MODEL

    # Log initial configuration
    logger.info(f"Starting Voice-to-Text Tool")
    logger.info(f"Base URL: {base_url}")
    logger.info(f"Model: {model}")
    logger.info(f"Log file: {LOG_FILE}")
    
    # Check if speaches.ai is running
    try:
        logger.info("Checking speaches.ai connection...")
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code != 200:
            logger.warning(f"speaches.ai might not be running at {base_url} (status: {response.status_code})")
        else:
            logger.info("speaches.ai connection successful")
    except requests.RequestException as e:
        logger.error(f"Cannot connect to speaches.ai at {base_url}: {e}")
        logger.error("Make sure speaches.ai is running.")
        sys.exit(1)

    # Create and run the voice-to-text system
    vtt = VoiceToText(base_url, model)
    vtt.listen_and_transcribe()


if __name__ == "__main__":
    main()
