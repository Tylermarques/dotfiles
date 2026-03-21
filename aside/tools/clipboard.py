"""Read and write the Wayland clipboard via wl-copy / wl-paste."""

import subprocess
from pathlib import Path

TOOL_SPEC = {
    "name": "clipboard",
    "description": (
        "Interact with the system clipboard (Wayland).\n\n"
        "Actions:\n"
        "- read: Return the current clipboard contents.\n"
        "- write: Copy the given text to the clipboard.\n"
        "- write_file: Copy the contents of a file to the clipboard."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["read", "write", "write_file"],
                "description": "What to do with the clipboard.",
            },
            "text": {
                "type": "string",
                "description": "For 'write': the text to copy to the clipboard.",
            },
            "file": {
                "type": "string",
                "description": "For 'write_file': path to a file whose contents should be copied.",
            },
        },
        "required": ["action"],
    },
}


def run(action: str, text: str | None = None, file: str | None = None) -> str:
    """Execute a clipboard action."""
    if action == "read":
        result = subprocess.run(
            ["wl-paste"], capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0:
            return f"Error reading clipboard: {result.stderr.strip()}"
        content = result.stdout
        if not content:
            return "Clipboard is empty."
        return content

    elif action == "write":
        if not text:
            return "Error: 'text' is required for write."
        subprocess.run(
            ["wl-copy"], input=text, text=True, timeout=5, check=True
        )
        return "Copied to clipboard."

    elif action == "write_file":
        if not file:
            return "Error: 'file' is required for write_file."
        path = Path(file).expanduser()
        if not path.is_file():
            return f"Error: file not found: {path}"
        with open(path, "rb") as f:
            subprocess.run(["wl-copy"], stdin=f, timeout=5, check=True)
        return f"Copied contents of {path.name} to clipboard."

    return f"Unknown action: {action}"
