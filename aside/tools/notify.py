"""Send desktop notifications via notify-send."""

import subprocess

TOOL_SPEC = {
    "name": "notify",
    "description": (
        "Send a desktop notification. Use this when the user asks to be "
        "notified or you want to surface information visually."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "title": {
                "type": "string",
                "description": "Notification title.",
            },
            "body": {
                "type": "string",
                "description": "Notification body text.",
            },
            "urgency": {
                "type": "string",
                "enum": ["low", "normal", "critical"],
                "description": "Urgency level (default: normal).",
            },
            "timeout": {
                "type": "integer",
                "description": "Auto-dismiss after this many milliseconds.",
            },
        },
        "required": ["title", "body"],
    },
}


def run(
    title: str,
    body: str,
    urgency: str = "normal",
    timeout: int | None = None,
) -> str:
    """Send a desktop notification."""
    cmd = ["notify-send", f"--urgency={urgency}"]
    if timeout is not None:
        cmd.append(f"--expire-time={timeout}")
    cmd += [title, body]
    subprocess.run(cmd, timeout=5, check=True)
    return f"Notification sent: {title}"
