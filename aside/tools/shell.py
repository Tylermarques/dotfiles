"""Restricted shell — run read-only system commands from an allowlist."""

import re
import shlex
import subprocess

ALLOWLIST = {
    "ls", "find", "cat", "head", "tail", "wc", "date", "cal",
    "df", "free", "uptime", "whoami", "pwd", "file", "stat",
    "du", "sort", "uniq", "tr", "cut", "column",
}

# Patterns that could be used to chain or escape to disallowed commands
_DANGEROUS = re.compile(r"[;|&`]|\$\(")

MAX_OUTPUT = 4000

TOOL_SPEC = {
    "name": "shell",
    "description": (
        "Run a read-only shell command from a restricted allowlist. "
        "Useful for checking disk space, listing files, reading file "
        "contents, and other safe system queries.\n\n"
        "Allowed commands: " + ", ".join(sorted(ALLOWLIST)) + "\n\n"
        "Pipes, semicolons, backticks, and $() are blocked."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "command": {
                "type": "string",
                "description": "The shell command to run.",
            },
        },
        "required": ["command"],
    },
}


def run(command: str) -> str:
    """Validate and execute a restricted shell command."""
    command = command.strip()
    if not command:
        return "Error: empty command."

    # Block dangerous patterns
    if _DANGEROUS.search(command):
        return "Error: pipes, semicolons, backticks, and $() are not allowed."

    # Check first word against allowlist
    first_word = command.split()[0]
    if first_word not in ALLOWLIST:
        return f"Error: '{first_word}' is not in the allowed command list."

    try:
        result = subprocess.run(
            shlex.split(command),
            capture_output=True,
            text=True,
            timeout=15,
        )
        output = result.stdout + result.stderr
        if len(output) > MAX_OUTPUT:
            output = output[:MAX_OUTPUT] + "\n... (truncated)"
        return output if output.strip() else "(no output)"
    except subprocess.TimeoutExpired:
        return "Error: command timed out after 15 seconds."
