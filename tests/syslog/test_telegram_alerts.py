from __future__ import annotations

import json
from io import BytesIO
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from features.syslog.telegram.renderer import MAX_TELEGRAM_TEXT, render_telegram
from features.syslog.telegram.service import (
    TelegramAlertService,
    TelegramDeliveryError,
    delivery_error_message,
    send_telegram_message,
)
from features.syslog.telegram.settings import (
    TelegramAlertSettingsStore,
    TelegramAlertValidationError,
)
from tests.syslog.test_email_alerts import _record


BOT_TOKEN = "123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghi"


def _payload(**updates):
    values = {
        "enabled": True,
        "bot_token": BOT_TOKEN,
        "chat_id": "-1001234567890",
        "levels": [0, 2, 4],
        "cooldown_seconds": 300,
        "batch_seconds": 0,
    }
    values.update(updates)
    return values


class TelegramAlertSettingsTests(unittest.TestCase):
    def test_token_is_encrypted_and_never_returned_to_qml(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "telegram_alerts.json"
            store = TelegramAlertSettingsStore(path)
            store.save(_payload())

            public = store.public_values()
            stored = json.loads(path.read_text(encoding="utf-8"))
            self.assertTrue(public["has_token"])
            self.assertEqual(public["bot_token"], "")
            self.assertNotIn(BOT_TOKEN, json.dumps(public))
            self.assertTrue(stored["bot_token"].startswith("ENC$v2$"))
            self.assertNotIn(BOT_TOKEN, json.dumps(stored))
            self.assertEqual(store.configuration().bot_token, BOT_TOKEN)
            if os.name != "nt":
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_blank_token_keeps_saved_token_and_chat_id_is_validated(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = TelegramAlertSettingsStore(Path(temporary) / "telegram.json")
            store.save(_payload())
            updated = store.save(_payload(bot_token="", chat_id="123456"))
            self.assertEqual(updated.bot_token, BOT_TOKEN)
            self.assertEqual(updated.chat_id, "123456")
            with self.assertRaises(TelegramAlertValidationError) as raised:
                store.save(_payload(chat_id="not a chat"))
            self.assertIn("chat_id", raised.exception.errors)


class TelegramRendererTests(unittest.TestCase):
    def test_renderer_is_bilingual_and_respects_bot_api_limit(self) -> None:
        record = _record()
        en = render_telegram(record, "en")
        vi = render_telegram(record, "vi", test=True)
        self.assertIn("SYSLOG ALERT", en)
        self.assertIn("Device: RT-EDGE-02", en)
        self.assertIn("CẢNH BÁO SYSLOG", vi)
        self.assertIn("[THỬ]", vi)

        many = []
        for index in range(100):
            row = _record(mnemonic=f"EVENT{index}")
            row["message"] = "x" * 200
            many.append(row)
        rendered = render_telegram(many, "en")
        self.assertLessEqual(len(rendered), MAX_TELEGRAM_TEXT)
        self.assertIn("more alert", rendered)


class TelegramDeliveryTests(unittest.TestCase):
    def test_sender_posts_chat_id_and_message_without_parse_mode(self) -> None:
        class Response:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            @staticmethod
            def read():
                return b'{"ok": true, "result": {"message_id": 1}}'

        with tempfile.TemporaryDirectory() as temporary:
            store = TelegramAlertSettingsStore(Path(temporary) / "telegram.json")
            config = store.save(_payload())
            with patch(
                "features.syslog.telegram.service.urlopen", return_value=Response()
            ) as mocked:
                text = send_telegram_message(config, [_record()], "en")
        request = mocked.call_args.args[0]
        body = request.data.decode("utf-8")
        self.assertIn("chat_id=-1001234567890", body)
        self.assertIn("text=", body)
        self.assertNotIn("parse_mode", body)
        self.assertIn("SYSLOG ALERT", text)

    def test_delivery_error_is_localized_without_exposing_token(self) -> None:
        exc = TelegramDeliveryError("Unauthorized", status=401)
        message = delivery_error_message(exc, "vi")
        self.assertIn("Bot Token", message)
        self.assertIn("401", message)
        self.assertNotIn(BOT_TOKEN, message)

    def test_api_error_cannot_echo_the_bot_token(self) -> None:
        error = HTTPError(
            "https://api.telegram.org/redacted",
            400,
            "Bad Request",
            {},
            BytesIO(
                json.dumps(
                    {"ok": False, "description": f"invalid {BOT_TOKEN}"}
                ).encode("utf-8")
            ),
        )
        try:
            with tempfile.TemporaryDirectory() as temporary:
                store = TelegramAlertSettingsStore(Path(temporary) / "telegram.json")
                config = store.save(_payload())
                with patch(
                    "features.syslog.telegram.service.urlopen", side_effect=error
                ):
                    with self.assertRaises(TelegramDeliveryError) as raised:
                        send_telegram_message(config, [_record()], "en")
        finally:
            error.close()
        self.assertNotIn(BOT_TOKEN, str(raised.exception))
        self.assertIn("[redacted]", str(raised.exception))


class TelegramAlertServiceTests(unittest.TestCase):
    def test_selected_levels_are_delivered_and_duplicates_suppressed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = TelegramAlertSettingsStore(Path(temporary) / "telegram.json")
            store.save(_payload(levels=[2], cooldown_seconds=300))
            delivered: list[list[dict]] = []
            completed = threading.Event()

            def sender(_config, records, _language, _test):
                delivered.append(records)
                completed.set()
                return "sent"

            service = TelegramAlertService(store, sender=sender)
            try:
                self.assertEqual(service.submit([_record(3)]), 0)
                self.assertEqual(service.submit([_record(2)]), 1)
                self.assertEqual(service.submit([_record(2)]), 0)
                self.assertTrue(completed.wait(2.0))
            finally:
                service.shutdown()
            self.assertEqual(len(delivered), 1)
            self.assertEqual(delivered[0][0]["severity"], 2)

    def test_disabled_configuration_never_sends(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = TelegramAlertSettingsStore(Path(temporary) / "telegram.json")
            store.save(_payload(enabled=False))
            delivered = []
            service = TelegramAlertService(
                store, sender=lambda *_args: delivered.append(True) or "sent"
            )
            try:
                self.assertEqual(service.submit([_record(2)]), 0)
            finally:
                service.shutdown()
            self.assertEqual(delivered, [])


if __name__ == "__main__":
    unittest.main()
