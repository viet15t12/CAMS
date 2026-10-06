from __future__ import annotations

import re
from typing import Any

from .cli_validation import has_rejected_command


# Backward-compatible private name retained for focused unit tests and callers.
_has_rejected_command = has_rejected_command


def _prompt_mode(output: str) -> str:
    """Classify the last visible Cisco IOS prompt after a timing read."""
    lines = [line.strip() for line in str(output).splitlines() if line.strip()]
    prompt = re.sub(r"(?:\x00|\^@)+$", "", lines[-1]).strip() if lines else ""
    if re.fullmatch(r"[^\s\r\n]+\(config(?:-[^)]+)?\)#", prompt):
        return "config"
    if re.fullmatch(r"[^\s\r\n()]+#", prompt):
        return "exec"
    return "unknown"


def apply_commands(connector: Any, commands: list[str]) -> str:
    connection = getattr(connector, "connection", None)
    if connection is None:
        raise RuntimeError("The active device session is unavailable")
    # Virtual IOS can omit the prompt during Netmiko's check_config_mode()
    # probe, which waits for [>#] before and after send_config_set().  Use
    # timing reads for those two mode transitions, while still letting
    # send_config_set() collect the complete IOS response for error checking.
    # Never replay the configuration after a timeout: some commands may have
    # already reached the switch.
    timing_sender = getattr(connection, "send_command_timing", None)
    if callable(timing_sender):
        timing_options = {
            "read_timeout": 60,
            "last_read": 0.5,
            "cmd_verify": False,
            "strip_prompt": False,
            "strip_command": False,
        }
        mode = _prompt_mode(timing_sender("", **timing_options))
        if mode == "config":
            mode = _prompt_mode(timing_sender("end", **timing_options))
        if mode != "exec":
            raise RuntimeError("The switch did not return a privileged EXEC prompt before Push")

        enter_output = str(timing_sender("configure terminal", **timing_options))
        if _prompt_mode(enter_output) != "config":
            raise RuntimeError("The switch did not enter configuration mode")

        output = str(connection.send_config_set(
            commands, read_timeout=60, cmd_verify=False,
            enter_config_mode=False, exit_config_mode=False,
        ))
        exit_output = str(timing_sender("end", **timing_options))
        output += exit_output
        if _prompt_mode(exit_output) != "exec":
            raise RuntimeError(
                "The switch did not confirm an EXEC prompt after Push; "
                "device state is uncertain. Inspect the interface and retry."
            )
    else:
        output = str(
            connection.send_config_set(commands, read_timeout=60, cmd_verify=False)
        )
    if has_rejected_command(output):
        raise RuntimeError(output.strip() or "The switch rejected the configuration")
    return output
