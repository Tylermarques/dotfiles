"""Set a reminder that fires a desktop notification after a delay."""

import subprocess

TOOL_SPEC = {
    "name": "timer",
    "description": (
        "Set a reminder notification that fires after a given number of "
        "minutes. Use this when the user says things like 'remind me in "
        "5 minutes' or 'set a timer for 10 minutes'."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "minutes": {
                "type": "integer",
                "description": "How many minutes until the reminder fires.",
            },
            "message": {
                "type": "string",
                "description": "The reminder message to display.",
            },
        },
        "required": ["minutes", "message"],
    },
}


def run(minutes: int, message: str) -> str:
    """Spawn a background process that sleeps then sends a notification."""
    if minutes < 1:
        return "Error: minutes must be at least 1."
    seconds = minutes * 60
    # Spawn detached so it survives after this process returns
    subprocess.Popen(
        ["bash", "-c", f'sleep {seconds} && notify-send --urgency=normal "Aside Reminder" {subprocess.list2cmdline([message])}'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return f"Timer set: will remind you in {minutes} minute{'s' if minutes != 1 else ''}."
