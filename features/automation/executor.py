"""Execute versioned CAMS actions through the app-owned SSH session."""

from __future__ import annotations

import re
import time
import uuid
from typing import Any

from features.syslog.persistence.message_repository import MessageRepository


_INTERFACE_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9./_-]{0,127}$")
_MAX_CLI_COMMANDS = 100
_MAX_VERIFY_COMMANDS = 20
_MAX_CLI_COMMAND_LENGTH = 512
_MAX_CLI_TOTAL_LENGTH = 16 * 1024
_CLI_ERROR_MARKERS = (
    "% invalid input",
    "% incomplete command",
    "% ambiguous command",
    "% authorization failed",
)


class AutomationActionExecutor:
    """Run typed v1 actions and bounded v2 CLI sequences over active SSH."""

    def __init__(
        self,
        session_registry: Any,
        *,
        verify_timeout: float = 10.0,
        poll_interval: float = 0.5,
    ) -> None:
        self._sessions = session_registry
        self._verify_timeout = max(0.0, min(float(verify_timeout), 30.0))
        self._poll_interval = max(0.05, min(float(poll_interval), 2.0))
        self._lease_owner = f"cams-auto-{uuid.uuid4().hex}"

    def execute_ready(
        self, repository: MessageRepository, limit: int = 10,
    ) -> dict[str, int]:
        """Claim and finish up to ``limit`` queued actions synchronously."""
        result = {"verified": 0, "noop_verified": 0, "failed": 0}
        for _ in range(max(0, min(int(limit), 100))):
            action = repository.claim_next_auto_action(self._lease_owner)
            if action is None:
                break
            status = self._execute_one(repository, action)
            result[status] += 1
        return result

    def _execute_one(
        self, repository: MessageRepository, action: dict[str, Any],
    ) -> str:
        action_id = int(action["id"])
        before: dict[str, Any] = {}
        after: dict[str, Any] = {}
        try:
            repository.begin_auto_action(action_id, self._lease_owner)
            request = action.get("request_redacted")
            if not isinstance(request, dict):
                raise ValueError("Auto action request is missing")
            action_type = str(action.get("action_type") or "")
            host = str(action.get("device_host") or "").strip()
            if action_type == "interface.admin-state":
                if request.get("transport") != "ssh":
                    raise ValueError("Auto interface actions require SSH transport")
                interface = str(request.get("interface") or "").strip()
                enabled = request.get("enabled")
                if not _INTERFACE_PATTERN.fullmatch(interface):
                    raise ValueError("Auto action interface is invalid")
                if not isinstance(enabled, bool):
                    raise ValueError("Auto action enabled value is invalid")
                operation = lambda connector: self._apply_interface_state(
                    connector, interface, enabled
                )
            elif action_type == "ssh.cli":
                mode, commands, verify_commands = self._validated_cli_request(request)
                operation = lambda connector: self._apply_cli_commands(
                    connector, mode, commands, verify_commands
                )
            else:
                raise ValueError("Auto executor rejected an unsupported action type")
            execution = self._sessions.execute(
                host,
                operation,
                ensure_open=False,
                lock_timeout=5.0,
            )
            if not bool(execution.get("ok")):
                raise RuntimeError(
                    str(execution.get("message") or "Device session execution failed")
                )
            value = execution.get("value")
            if not isinstance(value, dict):
                raise RuntimeError("Device session returned no verification result")
            before = dict(value.get("before") or {})
            after = dict(value.get("after") or {})
            status = "noop_verified" if value.get("noop") else "verified"
            repository.finish_auto_action(
                action_id,
                self._lease_owner,
                status,
                before=before,
                after=after,
            )
            return status
        except Exception as exc:
            repository.finish_auto_action(
                action_id,
                self._lease_owner,
                "failed",
                before=before,
                after=after,
                error=str(exc),
            )
            return "failed"

    @staticmethod
    def _validated_cli_list(
        value: Any, label: str, *, maximum: int, required: bool,
    ) -> list[str]:
        if not isinstance(value, list):
            raise ValueError(f"{label} must be a list")
        if required and not value:
            raise ValueError(f"{label} must not be empty")
        if len(value) > maximum:
            raise ValueError(f"{label} contains too many commands")
        commands: list[str] = []
        for command in value:
            if not isinstance(command, str):
                raise ValueError(f"{label} must contain strings")
            normalized = command.strip()
            if (
                not normalized
                or len(normalized) > _MAX_CLI_COMMAND_LENGTH
                or "\n" in command
                or "\r" in command
                or "\x00" in command
            ):
                raise ValueError(f"{label} contains an invalid CLI command")
            commands.append(normalized)
        if sum(len(command) for command in commands) > _MAX_CLI_TOTAL_LENGTH:
            raise ValueError(f"{label} is too large")
        return commands

    @classmethod
    def _validated_cli_request(
        cls, request: dict[str, Any],
    ) -> tuple[str, list[str], list[str]]:
        if request.get("rule_version") != 2:
            raise ValueError("SSH CLI actions require rule version 2")
        if request.get("transport") != "ssh":
            raise ValueError("SSH CLI actions require SSH transport")
        mode = str(request.get("mode") or "")
        if mode not in {"config", "exec"}:
            raise ValueError("SSH CLI action mode must be config or exec")
        commands = cls._validated_cli_list(
            request.get("commands"),
            "SSH CLI commands",
            maximum=_MAX_CLI_COMMANDS,
            required=True,
        )
        verify_commands = cls._validated_cli_list(
            request.get("verify_commands", []),
            "SSH CLI verification commands",
            maximum=_MAX_VERIFY_COMMANDS,
            required=False,
        )
        return mode, commands, verify_commands

    def _apply_cli_commands(
        self,
        connector: Any,
        mode: str,
        commands: list[str],
        verify_commands: list[str],
    ) -> dict[str, Any]:
        connection = self._require_ssh_connection(connector)
        outputs: list[dict[str, Any]] = []
        if mode == "config":
            output = str(connection.send_config_set(
                commands,
                read_timeout=120,
                cmd_verify=False,
            ) or "")
            self._raise_cli_error(output, "version 2 configuration")
            outputs.append({"stage": "config", "output": output[-4000:]})
        else:
            for command in commands:
                output = self._send_show(connector, command)
                self._raise_cli_error(output, f"version 2 exec command {command}")
                outputs.append({"stage": "exec", "output": output[-4000:]})

        verification: list[dict[str, str]] = []
        for command in verify_commands:
            output = self._send_show(connector, command)
            self._raise_cli_error(output, f"version 2 verification command {command}")
            verification.append({"command": command, "output": output[-4000:]})
        return {
            "before": {"mode": mode, "command_count": len(commands)},
            "after": {
                "mode": mode,
                "command_count": len(commands),
                "outputs": outputs,
                "verification": verification,
                "verification_mode": (
                    "commands" if verify_commands else "cli-accepted"
                ),
            },
            "noop": False,
        }

    def _apply_interface_state(
        self, connector: Any, interface: str, enabled: bool,
    ) -> dict[str, Any]:
        connection = self._require_ssh_connection(connector)
        before = self._read_interface_state(connector, interface)
        if before["enabled"] is enabled:
            return {"before": before, "after": before, "noop": True}

        command = "no shutdown" if enabled else "shutdown"
        output = str(connection.send_config_set(
            [f"interface {interface}", command],
            read_timeout=60,
            cmd_verify=False,
        ) or "")
        self._raise_cli_error(output, "interface configuration")

        deadline = time.monotonic() + self._verify_timeout
        after = self._read_interface_state(connector, interface)
        while after["enabled"] is not enabled and time.monotonic() < deadline:
            time.sleep(min(self._poll_interval, max(0.0, deadline - time.monotonic())))
            after = self._read_interface_state(connector, interface)
        if after["enabled"] is not enabled:
            expected = "enabled" if enabled else "administratively down"
            raise RuntimeError(
                f"Interface {interface} did not reach the expected state: {expected}"
            )
        return {"before": before, "after": after, "noop": False}

    @staticmethod
    def _require_ssh_connection(connector: Any) -> Any:
        connection = getattr(connector, "connection", None)
        if connection is None:
            raise RuntimeError("The active device session has no CLI connection")
        if str(getattr(connector, "method", "")).casefold() != "ssh":
            raise RuntimeError("Automation requires an active SSH session")
        return connection

    @classmethod
    def _read_interface_state(
        cls, connector: Any, interface: str,
    ) -> dict[str, Any]:
        outputs: list[str] = []
        for command in (
            f"show interfaces {interface}",
            f"show ip interface brief | include {interface}",
        ):
            output = cls._send_show(connector, command)
            if not output.strip():
                continue
            cls._raise_cli_error(output, "interface verification")
            outputs.append(output)
            matching_line = next(
                (
                    line.strip()
                    for line in output.splitlines()
                    if interface.casefold() in line.casefold()
                ),
                "",
            )
            if matching_line:
                normalized = matching_line.casefold()
                return {
                    "interface": interface,
                    "enabled": "administratively down" not in normalized,
                    "summary": matching_line[:500],
                }
        if not outputs:
            raise RuntimeError(f"Device returned no state for interface {interface}")
        raise RuntimeError(f"Device did not recognize interface {interface}")

    @staticmethod
    def _send_show(connector: Any, command: str) -> str:
        """Use CAMS prompt handling before falling back to a raw connection."""
        send_command = getattr(connector, "send_command", None)
        if callable(send_command):
            return str(send_command(command) or "")
        connection = getattr(connector, "connection", None)
        if connection is None:
            raise RuntimeError("The active device session has no CLI connection")
        return str(connection.send_command(
            command, read_timeout=30, cmd_verify=False
        ) or "")

    @staticmethod
    def _raise_cli_error(output: str, stage: str) -> None:
        normalized = output.casefold()
        if any(marker in normalized for marker in _CLI_ERROR_MARKERS):
            detail = next(
                (line.strip() for line in output.splitlines() if "%" in line),
                output.strip(),
            )
            raise RuntimeError(f"Cisco CLI rejected {stage}: {detail[:500]}")


__all__ = ["AutomationActionExecutor"]
