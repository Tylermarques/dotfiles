"""Open a URL in the default browser."""

import subprocess

TOOL_SPEC = {
    "name": "open_url",
    "description": "Open a URL in the user's default web browser.",
    "parameters": {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "The URL to open.",
            },
        },
        "required": ["url"],
    },
}


def run(url: str) -> str:
    """Open a URL with xdg-open."""
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    subprocess.Popen(
        ["xdg-open", url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return f"Opened {url} in browser."
