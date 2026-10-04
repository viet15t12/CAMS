from __future__ import annotations

import unittest

from core.database.view_push_slots import ViewPushSlotsMixin


class _Signal:
    def __init__(self) -> None:
        self.calls = []

    def emit(self, *values) -> None:
        self.calls.append(values)


class _Controller:
    def __init__(self) -> None:
        self.apply_calls = []

    def push_apply_only(self, host: str, module: str):
        self.apply_calls.append((host, module))
        return {
            "ok": True,
            "message": "Applied; synchronization continues in background.",
            "report": [{"status": "SUCCESS"}],
            "postPushPending": True,
        }


class _Factory:
    def __init__(self, controller: _Controller) -> None:
        self.controller = controller

    def get(self, _name: str) -> _Controller:
        return self.controller


class _Harness(ViewPushSlotsMixin):
    def __init__(self) -> None:
        self.controller = _Controller()
        self._view_push = _Factory(self.controller)
        self._background_tasks = {}
        self.viewPushFinished = _Signal()
        self.viewPushPreviewFinished = _Signal()
        self.runningConfigUpdated = _Signal()
        self.taskFinished = _Signal()
        self.started = []
        self.deferred = []
        self.deferred_contexts = []

    def _start_background_task(
        self, task_key, controller, host, module, message, callback, operation="push"
    ):
        self.started.append((task_key, operation, message))
        self.callback_result = callback(lambda _message: None)
        return True

    def _start_post_push_single(
        self, controller, host, module, post_push_context=None
    ):
        self.deferred.append((controller, host, module))
        self.deferred_contexts.append(post_push_context)
        return True


class ViewPushAsyncTests(unittest.TestCase):
    def test_vtp_client_snapshots_notify_ui_for_single_and_batch_completion(self) -> None:
        for operation in ("post-push-single", "post-push-batch"):
            with self.subTest(operation=operation):
                harness = _Harness()
                harness._background_tasks["sync"] = {"controller": "switching", "host": "server", "module": "vlan", "operation": operation}
                completion = {"host": "server", "reconciliation": {"snapshotUpdated": True}, "vtpClientReconciliation": {"results": [
                    {"host": "client1", "ok": True, "summary": {"snapshotUpdated": True}},
                    {"host": "client2", "ok": False, "summary": {"snapshotUpdated": False}},
                ]}}
                result = {"results": [completion]} if operation == "post-push-batch" else completion
                harness._handle_background_task_finished("sync", True, "synced", result)
                self.assertEqual(harness.runningConfigUpdated.calls, [("server",), ("client1",)])

    def test_single_async_push_uses_apply_only_controller_path(self) -> None:
        harness = _Harness()

        accepted = harness.pushViewPushAsync("routing", "192.0.2.1", "ospf")

        self.assertTrue(accepted)
        self.assertEqual(harness.controller.apply_calls, [("192.0.2.1", "ospf")])
        self.assertTrue(harness.callback_result["postPushPending"])

    def test_apply_completion_closes_dialog_before_scheduling_reconciliation(self) -> None:
        harness = _Harness()
        harness._background_tasks["apply"] = {
            "controller": "routing",
            "host": "192.0.2.1",
            "module": "ospf",
            "operation": "push",
        }
        result = {
            "ok": True,
            "message": "Applied.",
            "postPushPending": True,
        }

        harness._handle_background_task_finished(
            "apply", True, "Applied.", result
        )

        self.assertEqual(
            harness.viewPushFinished.calls,
            [("routing", "192.0.2.1", "ospf", True, "Applied.")],
        )
        self.assertEqual(harness.taskFinished.calls, [(True, "Applied.")])
        self.assertEqual(harness.deferred, [("routing", "192.0.2.1", "ospf")])

    def test_apply_completion_forwards_deferred_verification_context(self) -> None:
        harness = _Harness()
        harness._background_tasks["apply"] = {
            "controller": "fhrp",
            "host": "192.0.2.1",
            "module": "hsrp",
            "operation": "push",
        }
        context = [{"config": {"member_id": 7}}]

        harness._handle_background_task_finished(
            "apply",
            True,
            "Applied.",
            {
                "ok": True,
                "message": "Applied.",
                "postPushPending": True,
                "postPushContext": context,
            },
        )

        self.assertEqual(harness.deferred, [("fhrp", "192.0.2.1", "hsrp")])
        self.assertEqual(harness.deferred_contexts, [context])

    def test_background_completion_updates_snapshot_without_reopening_dialog(self) -> None:
        harness = _Harness()
        harness._background_tasks["sync"] = {
            "controller": "routing",
            "host": "192.0.2.1",
            "module": "ospf",
            "operation": "post-push-single",
        }

        harness._handle_background_task_finished(
            "sync",
            True,
            "Synchronized.",
            {"reconciliation": {"ok": True, "snapshotUpdated": True}},
        )

        self.assertEqual(harness.viewPushFinished.calls, [])
        self.assertEqual(harness.runningConfigUpdated.calls, [("192.0.2.1",)])
        self.assertEqual(harness.taskFinished.calls, [(True, "Synchronized.")])


if __name__ == "__main__":
    unittest.main()
