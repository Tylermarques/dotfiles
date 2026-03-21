"""Capture a screenshot using grim (and slurp for region selection)."""

import base64
import subprocess
import tempfile
from pathlib import Path

TOOL_SPEC = {
    "name": "screenshot",
    "description": (
        "Take a screenshot of the screen. Returns the image so you can "
        "see and describe what's on screen.\n\n"
        "Modes:\n"
        "- fullscreen: Capture the entire screen.\n"
        "- region: Let the user select a region with their cursor."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "mode": {
                "type": "string",
                "enum": ["fullscreen", "region"],
                "description": "Capture mode (default: fullscreen).",
            },
        },
        "required": [],
    },
}


def run(mode: str = "fullscreen") -> dict:
    """Capture a screenshot and return it as base64-encoded image data."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        if mode == "region":
            # slurp lets the user draw a selection rectangle
            geom = subprocess.run(
                ["slurp"], capture_output=True, text=True, timeout=30
            )
            if geom.returncode != 0:
                return "Region selection cancelled."
            subprocess.run(
                ["grim", "-g", geom.stdout.strip(), tmp_path],
                check=True, timeout=10,
            )
        else:
            subprocess.run(["grim", tmp_path], check=True, timeout=10)

        data = Path(tmp_path).read_bytes()
        return {
            "type": "image",
            "media_type": "image/png",
            "base64": base64.b64encode(data).decode(),
        }
    finally:
        Path(tmp_path).unlink(missing_ok=True)
