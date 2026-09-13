from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

import paramiko
from scp import SCPClient

from .sftp_service import (
    CaptureHostKeyPolicy,
    ConfirmedHostKeyPolicy,
    ConnectionOptions,
    UnknownHostKeyError,
)

ProgressCallback = Callable[[int, int], None]


class ScpService:
    """SCP transport for hosts that do not expose the SFTP subsystem."""

    def __init__(
        self,
        *,
        ssh_client_factory: Callable[[], Any] = paramiko.SSHClient,
        scp_client_factory: Callable[..., Any] = SCPClient,
        known_hosts_path: Path | None = None,
    ) -> None:
        self._ssh_client_factory = ssh_client_factory
        self._scp_client_factory = scp_client_factory
        self._known_hosts_path = (
            known_hosts_path or Path.home() / ".ssh" / "known_hosts"
        )
        self._ssh: Any | None = None
        self._pending_host_key: dict[str, str] | None = None

    @property
    def pending_host_key(self) -> dict[str, str] | None:
        return dict(self._pending_host_key) if self._pending_host_key else None

    def connect(self, options: ConnectionOptions, accepted_fingerprint: str = "") -> str:
        self.disconnect()
        self._pending_host_key = None
        ssh = self._ssh_client_factory()
        ssh.load_system_host_keys()
        if self._known_hosts_path.exists():
            ssh.load_host_keys(str(self._known_hosts_path))
        policy = (
            ConfirmedHostKeyPolicy(accepted_fingerprint, self._known_hosts_path)
            if accepted_fingerprint
            else CaptureHostKeyPolicy()
        )
        ssh.set_missing_host_key_policy(policy)
        arguments: dict[str, Any] = {
            "hostname": options.host,
            "port": options.port,
            "username": options.username,
            "password": options.password or None,
            "timeout": options.timeout,
            "banner_timeout": options.timeout,
            "auth_timeout": options.timeout,
            "look_for_keys": not bool(options.private_key),
            "allow_agent": True,
        }
        if options.private_key:
            arguments["key_filename"] = options.private_key
        try:
            ssh.connect(**arguments)
        except UnknownHostKeyError as exc:
            self._pending_host_key = exc.info
            ssh.close()
            raise
        except Exception:
            ssh.close()
            raise
        transport = ssh.get_transport()
        if transport is None or not transport.is_active():
            ssh.close()
            raise RuntimeError("The SCP SSH transport is unavailable")
        self._ssh = ssh
        return "/"

    def disconnect(self) -> None:
        if self._ssh is not None:
            try:
                self._ssh.close()
            finally:
                self._ssh = None

    def upload(
        self, local_path: str, remote_dir: str, callback: ProgressCallback
    ) -> None:
        source = Path(local_path)
        if not source.exists():
            raise FileNotFoundError(f"Local file not found: {source}")
        target = str(remote_dir or ".").strip().replace("\\", "/") or "."
        with self._client(callback) as client:
            client.put(
                str(source),
                remote_path=target,
                recursive=source.is_dir(),
                preserve_times=True,
            )

    def download(
        self, remote_path: str, local_dir: str, callback: ProgressCallback
    ) -> None:
        source = str(remote_path or "").strip().replace("\\", "/")
        if not source or source in {"/", "."}:
            raise ValueError(
                "Enter the full remote file or directory path for SCP download"
            )
        destination = Path(local_dir)
        if not destination.is_dir():
            raise ValueError("The selected local SCP directory does not exist")
        with self._client(callback) as client:
            client.get(
                source,
                local_path=str(destination),
                recursive=True,
                preserve_times=True,
            )

    def _client(self, callback: ProgressCallback) -> SCPClient:
        if self._ssh is None:
            raise RuntimeError("Not connected to an SCP server")
        transport = self._ssh.get_transport()
        if transport is None or not transport.is_active():
            raise RuntimeError("The SCP SSH transport is unavailable")

        def report(_filename: bytes, size: int, transferred: int) -> None:
            callback(int(transferred), int(size))

        return self._scp_client_factory(transport, progress=report)
