"""Qt lifecycle manager for the app-bound CAMS Automation Engine sidecar."""

from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

from PyQt6.QtCore import QObject, QTimer, pyqtProperty, pyqtSignal, pyqtSlot

from features.syslog.persistence.message_repository import MessageRepository
from infrastructure.database.paths import DATA_DIR, INFO_COLLECTED_DB

from .rules import RuleFileRepository, sample_icmp_rule_text


APP_DIR = Path(__file__).resolve().parents[2]
SERVICE_NAME = "CAMS Automation Engine"
SERVICE_COMMAND = "cams-automation"
PROTOCOL_VERSION = 1


def _file_url_to_path(value: str) -> Path:
    text = str(value or "").strip()
    parsed = urlparse(text)
    if parsed.scheme == "file":
        path = unquote(parsed.path)
        if parsed.netloc:
            path = f"//{parsed.netloc}{path}"
        if os.name == "nt" and path.startswith("/") and len(path) > 2 and path[2] == ":":
            path = path[1:]
        return Path(path)
    return Path(text)


class AutomationManager(QObject):
    stateChanged = pyqtSignal()
    rulesChanged = pyqtSignal()
    actionsChanged = pyqtSignal()
    errorOccurred = pyqtSignal(str)

    def __init__(
        self,
        parent: QObject | None = None,
        *,
        info_db: str | Path = INFO_COLLECTED_DB,
        rules_dir: str | Path | None = None,
        project_id: str = "default",
        command: list[str] | None = None,
        autostart: bool = False,
    ) -> None:
        super().__init__(parent)
        self._state_lock = threading.RLock()
        self._process_lock = threading.RLock()
        self._repository_lock = threading.RLock()
        self._state = "stopped"
        self._status_message = f"{SERVICE_NAME} is stopped."
        self._rule_count = 0
        self._action_count = 0
        self._rule_errors: list[dict[str, str]] = []
        self._project_id = str(project_id or "default")
        self._info_db = Path(info_db)
        initial_rules = Path(rules_dir) if rules_dir is not None else DATA_DIR / "automation" / "rules"
        self._rules = RuleFileRepository(initial_rules)
        self._repository = MessageRepository(self._info_db)
        self._command_override = list(command) if command else None
        self._process: subprocess.Popen[str] | None = None
        self._response_queue: queue.Queue[dict[str, Any] | None] | None = None
        self._reader_thread: threading.Thread | None = None
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="cams-automation")
        self._busy_lock = threading.Lock()
        self._busy = False
        self._shutdown = False
        self._timer = QTimer(self)
        self._timer.setInterval(1000)
        self._timer.timeout.connect(self._schedule_evaluation)
        self._timer.start()
        self._refresh_counts()
        if autostart:
            QTimer.singleShot(0, self.start)

    @pyqtProperty(str, constant=True)
    def serviceName(self) -> str:
        return SERVICE_NAME

    @pyqtProperty(str, constant=True)
    def serviceCommand(self) -> str:
        return SERVICE_COMMAND

    @pyqtProperty(str, notify=stateChanged)
    def state(self) -> str:
        with self._state_lock:
            return self._state

    @pyqtProperty(str, notify=stateChanged)
    def statusMessage(self) -> str:
        with self._state_lock:
            return self._status_message

    @pyqtProperty(bool, notify=stateChanged)
    def running(self) -> bool:
        return self.state == "running"

    @pyqtProperty(bool, notify=stateChanged)
    def busy(self) -> bool:
        with self._busy_lock:
            return self._busy

    @pyqtProperty(int, notify=rulesChanged)
    def ruleCount(self) -> int:
        with self._state_lock:
            return self._rule_count

    @pyqtProperty(int, notify=actionsChanged)
    def actionCount(self) -> int:
        with self._state_lock:
            return self._action_count

    @pyqtProperty("QVariant", notify=rulesChanged)
    def ruleErrors(self) -> list[dict[str, str]]:
        with self._state_lock:
            return [dict(item) for item in self._rule_errors]

    @pyqtProperty(str, notify=rulesChanged)
    def rulesDirectory(self) -> str:
        with self._repository_lock:
            return str(self._rules.directory)

    def _set_state(self, state: str, message: str) -> None:
        with self._state_lock:
            self._state = state
            self._status_message = message
        self.stateChanged.emit()

    def _set_busy(self, value: bool) -> None:
        with self._busy_lock:
            changed = self._busy != value
            self._busy = value
        if changed:
            self.stateChanged.emit()

    @pyqtSlot(result="QVariant")
    def start(self) -> dict[str, Any]:
        if self._shutdown:
            return {"ok": False, "message": "Automation manager is shutting down."}
        if self.state in {"starting", "running"}:
            return {"ok": True, "message": self.statusMessage}
        self._set_state("starting", f"Starting {SERVICE_NAME}...")
        self._executor.submit(self._start_worker)
        return {"ok": True, "message": f"Starting {SERVICE_NAME}..."}

    def _start_worker(self) -> None:
        try:
            with self._process_lock:
                self._stop_process_locked()
                command, cwd = self._resolve_command()
                environment = dict(os.environ)
                for name in tuple(environment):
                    if name == "CAMS_CREDENTIAL_KEY" or name.startswith("CAMS_SECRET_"):
                        environment.pop(name, None)
                process = subprocess.Popen(
                    command,
                    cwd=str(cwd) if cwd else None,
                    env=environment,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    encoding="utf-8",
                    bufsize=1,
                )
                self._process = process
                responses: queue.Queue[dict[str, Any] | None] = queue.Queue()
                self._response_queue = responses
                self._reader_thread = threading.Thread(
                    target=self._read_responses,
                    args=(process, responses),
                    name="cams-automation-reader",
                    daemon=True,
                )
                self._reader_thread.start()
                with self._repository_lock:
                    project_id = self._project_id
                    rules_dir = str(self._rules.directory)
                self._request_locked("hello", {
                    "mode": "dry-run", "project_id": project_id,
                    "rules_dir": rules_dir,
                })
            self._set_state("running", f"{SERVICE_NAME} is running in dry-run mode.")
        except Exception as exc:
            with self._process_lock:
                self._stop_process_locked()
            self._set_state("error", str(exc))
            self.errorOccurred.emit(str(exc))

    @staticmethod
    def _read_responses(
        process: subprocess.Popen[str],
        responses: queue.Queue[dict[str, Any] | None],
    ) -> None:
        assert process.stdout is not None
        try:
            for line in process.stdout:
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    responses.put({"ok": False, "error": "Sidecar returned invalid JSON"})
                    continue
                responses.put(value if isinstance(value, dict) else {
                    "ok": False, "error": "Sidecar response must be an object",
                })
        finally:
            responses.put(None)

    def _resolve_command(self) -> tuple[list[str], Path | None]:
        if self._command_override:
            return [*self._command_override, "serve", "--stdio"], None
        override = os.environ.get("CAMS_AUTOMATION_BINARY", "").strip()
        candidates = [
            Path(override) if override else None,
            APP_DIR / "bin" / SERVICE_COMMAND,
            APP_DIR / "bin" / "gocore",
        ]
        for candidate in candidates:
            if candidate is not None and candidate.is_file() and os.access(candidate, os.X_OK):
                return [str(candidate), "serve", "--stdio"], None
        installed = shutil.which(SERVICE_COMMAND) or shutil.which("gocore")
        if installed:
            return [installed, "serve", "--stdio"], None
        go = shutil.which("go")
        go_module = APP_DIR / "gocore" / "go.mod"
        if go and go_module.is_file():
            return [go, "run", "./cmd/gocore", "serve", "--stdio"], go_module.parent
        raise FileNotFoundError(
            "cams-automation was not found. Run install.sh or build gocore/cmd/gocore."
        )

    def _request_locked(self, message_type: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        process = self._process
        responses = self._response_queue
        if process is None or process.stdin is None or responses is None or process.poll() is not None:
            raise RuntimeError(f"{SERVICE_NAME} is not running")
        request_id = uuid.uuid4().hex
        request: dict[str, Any] = {
            "protocol_version": PROTOCOL_VERSION,
            "type": message_type,
            "request_id": request_id,
        }
        if payload is not None:
            request["payload"] = payload
        process.stdin.write(json.dumps(request, ensure_ascii=False, separators=(",", ":")) + "\n")
        process.stdin.flush()
        try:
            response = responses.get(timeout=10.0)
        except queue.Empty as exc:
            raise TimeoutError(f"{SERVICE_NAME} did not respond within 10 seconds") from exc
        if response is None:
            raise RuntimeError(f"{SERVICE_NAME} stopped unexpectedly")
        if response.get("request_id") != request_id:
            raise RuntimeError("Automation sidecar response id mismatch")
        if response.get("protocol_version") != PROTOCOL_VERSION:
            raise RuntimeError("Automation sidecar protocol version mismatch")
        if response.get("ok") is not True:
            raise RuntimeError(str(response.get("error") or "Automation sidecar request failed"))
        return response

    def _schedule_evaluation(self) -> None:
        if self._shutdown or self.state != "running":
            return
        with self._busy_lock:
            if self._busy:
                return
            self._busy = True
        self.stateChanged.emit()
        self._executor.submit(self._evaluate_once)

    def _evaluate_once(self) -> None:
        try:
            with self._repository_lock:
                repository = self._repository
            events = repository.query_pending_automation_events(100)
            with self._process_lock:
                response = self._request_locked("evaluate", {"events": events})
            payload = response.get("payload")
            if not isinstance(payload, dict):
                raise RuntimeError("Automation sidecar omitted evaluate payload")
            actions = payload.get("actions", [])
            processed = payload.get("processed_event_ids", [])
            deferred = payload.get("deferred_event_ids", [])
            rule_errors = payload.get("rule_errors", [])
            if not isinstance(actions, list) or not isinstance(processed, list):
                raise RuntimeError("Automation sidecar returned an invalid evaluate payload")
            result = repository.materialize_automation_actions(actions, processed)
            loaded_rules = max(0, int(payload.get("loaded_rules", 0)))
            safe_errors = [
                {"file": str(item.get("file") or ""), "error": str(item.get("error") or "")}
                for item in rule_errors if isinstance(item, dict)
            ]
            with self._state_lock:
                self._rule_count = loaded_rules
                self._action_count = len(repository.query_automation_actions(500))
                self._rule_errors = safe_errors
                self._status_message = (
                    f"Dry-run active: {loaded_rules} rule(s), "
                    f"{result['inserted']} new action(s), {len(deferred)} deferred event(s)."
                )
            self.rulesChanged.emit()
            if result["inserted"] or result["suppressed"]:
                self.actionsChanged.emit()
            self.stateChanged.emit()
        except Exception as exc:
            with self._process_lock:
                self._stop_process_locked()
            self._set_state("error", str(exc))
            self.errorOccurred.emit(str(exc))
        finally:
            self._set_busy(False)

    def set_workspace(
        self,
        info_db: str | Path,
        rules_dir: str | Path,
        project_id: str,
    ) -> None:
        if self._shutdown:
            return
        self._set_state("starting", f"Rebinding {SERVICE_NAME} to the active workspace...")
        self._executor.submit(
            self._rebind_worker, Path(info_db), Path(rules_dir), str(project_id or "default")
        )

    def _rebind_worker(self, info_db: Path, rules_dir: Path, project_id: str) -> None:
        try:
            with self._process_lock:
                self._stop_process_locked()
            with self._repository_lock:
                self._info_db = info_db
                self._project_id = project_id
                self._rules = RuleFileRepository(rules_dir)
                self._repository = MessageRepository(info_db)
            self._refresh_counts()
            self.rulesChanged.emit()
            self.actionsChanged.emit()
            self._start_worker()
        except Exception as exc:
            self._set_state("error", str(exc))
            self.errorOccurred.emit(str(exc))

    @pyqtSlot(result="QVariant")
    def stop(self) -> dict[str, Any]:
        if self.state == "stopped":
            return {"ok": True, "message": self.statusMessage}
        self._set_state("stopping", f"Stopping {SERVICE_NAME}...")
        self._executor.submit(self._stop_worker)
        return {"ok": True, "message": f"Stopping {SERVICE_NAME}..."}

    def _stop_worker(self) -> None:
        with self._process_lock:
            self._stop_process_locked()
        if not self._shutdown:
            self._set_state("stopped", f"{SERVICE_NAME} is stopped.")

    def _stop_process_locked(self) -> None:
        process = self._process
        if process is None:
            return
        if process.poll() is None:
            try:
                self._request_locked("shutdown")
            except Exception:
                pass
        try:
            process.wait(timeout=2.0)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2.0)
        if process.stdin is not None:
            process.stdin.close()
        if process.stdout is not None:
            process.stdout.close()
        self._process = None
        self._response_queue = None
        self._reader_thread = None

    def _refresh_counts(self) -> None:
        with self._repository_lock:
            rules = self._rules.list_rules()
            actions = self._repository.query_automation_actions(500)
        with self._state_lock:
            self._rule_count = sum(1 for item in rules if item["valid"])
            self._action_count = len(actions)

    @pyqtSlot(result="QVariant")
    def getRules(self) -> list[dict[str, Any]]:
        try:
            with self._repository_lock:
                rules = self._rules.list_rules()
            with self._state_lock:
                self._rule_count = sum(1 for item in rules if item["valid"])
            return rules
        except Exception as exc:
            self.errorOccurred.emit(str(exc))
            return []

    @pyqtSlot(str, result="QVariant")
    def getRule(self, rule_id: str) -> dict[str, Any]:
        try:
            with self._repository_lock:
                text = self._rules.get_rule_text(rule_id)
            return {"ok": True, "text": text}
        except Exception as exc:
            return {"ok": False, "message": str(exc), "text": ""}

    @pyqtSlot(str, result="QVariant")
    def saveRule(self, text: str) -> dict[str, Any]:
        try:
            with self._repository_lock:
                result = self._rules.save_rule_text(str(text))
            self.getRules()
            self.rulesChanged.emit()
            return result
        except Exception as exc:
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(str, result="QVariant")
    def importRule(self, file_url: str) -> dict[str, Any]:
        try:
            with self._repository_lock:
                result = self._rules.import_rule(_file_url_to_path(file_url))
            self.getRules()
            self.rulesChanged.emit()
            return result
        except Exception as exc:
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(str, bool, result="QVariant")
    def setRuleEnabled(self, rule_id: str, enabled: bool) -> dict[str, Any]:
        try:
            with self._repository_lock:
                result = self._rules.set_enabled(rule_id, enabled)
            self.getRules()
            self.rulesChanged.emit()
            return result
        except Exception as exc:
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(str, result="QVariant")
    def deleteRule(self, rule_id: str) -> dict[str, Any]:
        try:
            with self._repository_lock:
                result = self._rules.delete_rule(rule_id)
            self.getRules()
            self.rulesChanged.emit()
            return result
        except Exception as exc:
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(result=str)
    def sampleIcmpRule(self) -> str:
        return sample_icmp_rule_text()

    @pyqtSlot(result="QVariant")
    def getActions(self) -> list[dict[str, Any]]:
        try:
            with self._repository_lock:
                actions = self._repository.query_automation_actions(100)
            with self._state_lock:
                self._action_count = len(actions)
            return actions
        except Exception as exc:
            self.errorOccurred.emit(str(exc))
            return []

    def shutdown(self) -> None:
        if self._shutdown:
            return
        self._shutdown = True
        self._timer.stop()
        future = self._executor.submit(self._stop_worker)
        try:
            future.result(timeout=6.0)
        except Exception:
            pass
        self._executor.shutdown(wait=True, cancel_futures=True)
        with self._state_lock:
            self._state = "stopped"
            self._status_message = f"{SERVICE_NAME} is stopped."

    def prepare_workspace_close(self) -> None:
        """Synchronously release the active workspace before it is saved/removed."""
        if self._shutdown:
            return
        future = self._executor.submit(self._stop_worker)
        future.result(timeout=6.0)


__all__ = ["AutomationManager", "SERVICE_COMMAND", "SERVICE_NAME"]
