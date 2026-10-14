"""Bounded multi-host execution with isolated per-host results."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
import os
import threading
from typing import Any, Callable

HostWorker = Callable[[str], dict[str, Any]]
HostCallback = Callable[[str, str, str, int], None]
ProgressCallback = Callable[[int, int, int, int], None]


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


# One place for batch tuning; env vars let a lab raise or lower it without code.
HARD_MAX_CONCURRENT_HOSTS = 50
DEFAULT_MAX_CONCURRENT_HOSTS = _env_int("CAMS_MAX_CONCURRENT_HOSTS", 20)
# Canary rollout (Ansible serial + max_fail_percentage): the first N hosts must
# finish before the rest start, and no new host starts once failures exceed P%.
DEFAULT_CANARY_HOSTS = _env_int("CAMS_CANARY_HOSTS", 5)
DEFAULT_MAX_FAIL_PERCENT = _env_int("CAMS_MAX_FAIL_PERCENT", 30)


class BatchExecutor:
    def __init__(self, max_concurrent_hosts: int | None = None) -> None:
        if max_concurrent_hosts is None:
            max_concurrent_hosts = DEFAULT_MAX_CONCURRENT_HOSTS
        self.max_concurrent_hosts = min(
            HARD_MAX_CONCURRENT_HOSTS, max(1, int(max_concurrent_hosts))
        )

    def run(
        self,
        hosts: list[str],
        worker: HostWorker,
        *,
        cancel_event: threading.Event,
        on_host: HostCallback,
        on_progress: ProgressCallback,
        canary_hosts: int = 0,
        max_fail_percent: int = 100,
    ) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        counters = {"completed": 0, "success": 0, "failed": 0}
        queued = list(hosts)
        halted = threading.Event()
        canary = max(0, int(canary_hosts))
        fail_limit = max(0, int(max_fail_percent))

        def invoke(host: str) -> dict[str, Any]:
            if cancel_event.is_set():
                return {
                    "host": host, "ok": False, "severity": "cancelled",
                    "state": "cancelled", "message": "Cancelled before start.",
                }
            if halted.is_set():
                return {
                    "host": host, "ok": False, "severity": "cancelled",
                    "state": "cancelled", "halted": True,
                    "message": (
                        f"Skipped {host}: failure rate exceeded {fail_limit}%, "
                        "batch stopped."
                    ),
                }
            on_host(host, "running", f"Running operation for {host}.", 10)
            try:
                result = dict(worker(host) or {})
            except Exception as exc:
                result = {
                    "ok": False, "severity": "error",
                    "message": f"Operation failed for {host}: {exc}",
                }
            result["host"] = host
            result.setdefault("severity", "success" if result.get("ok") else "error")
            result.setdefault("message", f"Operation finished for {host}.")
            result["state"] = (
                "cancelled" if result["severity"] == "cancelled"
                else "success" if result.get("ok")
                else "error"
            )
            return result

        def record(result: dict[str, Any]) -> None:
            results.append(result)
            state = str(result["state"])
            on_host(
                str(result["host"]), state, str(result["message"]),
                100 if state != "cancelled" else 0,
            )
            counters["completed"] += 1
            if result.get("ok"):
                counters["success"] += 1
            elif state != "cancelled":
                counters["failed"] += 1
            finished = counters["success"] + counters["failed"]
            # Judge only after a full canary-sized sample so one early error
            # does not stop a 300-host rollout.
            if (
                fail_limit < 100
                and finished >= max(1, min(canary, len(queued)))
                and counters["failed"] * 100 > fail_limit * finished
            ):
                halted.set()
            on_progress(
                counters["completed"], counters["success"],
                counters["failed"], len(queued),
            )

        for host in queued:
            on_host(host, "queued", f"Queued {host}.", 0)
        on_progress(0, 0, 0, len(queued))

        waves = (
            [queued[:canary], queued[canary:]]
            if 0 < canary < len(queued) else [queued]
        )
        with ThreadPoolExecutor(
            max_workers=self.max_concurrent_hosts,
            thread_name_prefix="device-batch",
        ) as pool:
            for wave in waves:
                futures = [pool.submit(invoke, host) for host in wave]
                for future in as_completed(futures):
                    record(future.result())
        order = {host: index for index, host in enumerate(queued)}
        return sorted(results, key=lambda item: order[str(item["host"])])
