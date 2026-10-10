from __future__ import annotations

import smtplib
import socket
import ssl
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

from features.syslog.alerts.service import EmailAlertService, delivery_error_message, send_smtp_message
from features.syslog.alerts.settings import AlertSettingsStore, validate_configuration
from tests.syslog.test_email_alerts import _payload, _record


class SmtpDeliveryTests(unittest.TestCase):
    def setUp(self):
        implicit = patch("features.syslog.alerts.service.smtplib.SMTP_SSL")
        explicit = patch("features.syslog.alerts.service.smtplib.SMTP")
        self.implicit = implicit.start()
        self.explicit = explicit.start()
        self.addCleanup(implicit.stop)
        self.addCleanup(explicit.stop)
        self.implicit.return_value.send_message.return_value = {}
        self.explicit.return_value.send_message.return_value = {}

    def _send(self, **updates):
        config = validate_configuration(_payload(**updates))
        return send_smtp_message(config, [_record()], "en", True)

    def test_465_uses_verified_tls_before_authentication(self):
        implicit, explicit = self.implicit, self.explicit
        self.assertTrue(self._send().startswith("[TEST]"))
        explicit.assert_not_called()
        context = implicit.call_args.kwargs["context"]
        self.assertTrue(context.check_hostname)
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        server = implicit.return_value
        server.login.assert_called_once_with("sender@example.com", "abcdefghijklmnop")
        message = server.send_message.call_args.args[0]
        self.assertEqual(message["To"], "one@example.com, two@example.com")
        server.quit.assert_called_once()

    def test_587_negotiates_starttls_then_authenticates(self):
        explicit, implicit = self.explicit, self.implicit
        server = explicit.return_value
        server.send_message.return_value = {}
        self._send(smtp_port=587)
        implicit.assert_not_called()
        self.assertEqual(explicit.call_args.args, ("smtp.gmail.com", 587))
        self.assertEqual(
            [call[0] for call in server.method_calls],
            ["ehlo", "starttls", "ehlo", "login", "send_message", "quit", "close"],
        )
        context = server.starttls.call_args.kwargs["context"]
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)

    def test_no_authentication_if_starttls_is_unavailable(self):
        smtp = self.explicit
        smtp.return_value.starttls.side_effect = smtplib.SMTPNotSupportedError("no TLS")
        with self.assertRaises(Exception) as raised:
            self._send(smtp_port=587)
        smtp.return_value.login.assert_not_called()
        smtp.return_value.send_message.assert_not_called()
        smtp.return_value.close.assert_called_once()
        message = delivery_error_message(raised.exception, "en")
        self.assertIn("STARTTLS", message)
        self.assertIn("smtp.gmail.com:587", message)
        self.assertNotIn("Could not connect", message)

    def test_partial_recipient_refusal_is_not_reported_as_success(self):
        smtp = self.implicit
        smtp.return_value.send_message.return_value = {
            "two@example.com": (550, b"recipient rejected")
        }
        with self.assertRaises(Exception) as raised:
            self._send()
        message = delivery_error_message(raised.exception, "en")
        self.assertIn("1 of 2", message)
        self.assertIn("550", message)

    def test_quit_failure_does_not_mark_an_accepted_email_as_failed(self):
        smtp = self.implicit
        smtp.return_value.send_message.return_value = {}
        smtp.return_value.quit.side_effect = smtplib.SMTPServerDisconnected("closed")
        self.assertTrue(self._send().startswith("[TEST]"))
        smtp.return_value.send_message.assert_called_once()
        smtp.return_value.close.assert_called_once()

    def test_send_failure_keeps_the_original_stage_and_smtp_code(self):
        smtp = self.implicit
        smtp.return_value.send_message.side_effect = smtplib.SMTPDataError(554, b"rejected")
        smtp.return_value.close.side_effect = OSError("closed")
        with self.assertRaises(Exception) as raised:
            self._send()
        message = delivery_error_message(raised.exception, "en")
        self.assertIn("554", message)
        self.assertIn("smtp.gmail.com:465", message)
        self.assertNotIn("Could not connect", message)

    def test_server_protocol_and_tls_errors_are_distinct_from_network_errors(self):
        cases = (
            (smtplib.SMTPDataError(554, b"secret"), "554"),
            (smtplib.SMTPSenderRefused(550, b"secret", "sender@example.com"), "550"),
            (smtplib.SMTPRecipientsRefused({"one@example.com": (550, b"secret")}), "550"),
            (ssl.SSLCertVerificationError("secret"), "certificate"),
            (ssl.SSLError("secret"), "TLS"),
            (smtplib.SMTPServerDisconnected("secret"), "closed"),
        )
        for exc, expected in cases:
            with self.subTest(exception=type(exc).__name__):
                message = delivery_error_message(exc, "en")
                self.assertIn(expected, message)
                self.assertNotIn("Could not connect", message)
                self.assertNotIn("secret", message)

    def test_dns_timeout_and_refused_connection_have_actionable_messages(self):
        for exc, expected in (
            (socket.gaierror(socket.EAI_AGAIN, "secret"), "DNS"),
            (TimeoutError("secret"), "timed out"),
            (ConnectionRefusedError("secret"), "refused"),
        ):
            with self.subTest(exception=type(exc).__name__):
                self.assertIn(expected, delivery_error_message(exc, "en"))
                self.assertNotIn("secret", delivery_error_message(exc, "vi"))

    def test_custom_ports_allow_explicit_security_and_defaults_remain_compatible(self):
        self.assertEqual(validate_configuration(_payload()).transport_security, "ssl")
        self.assertEqual(validate_configuration(_payload(smtp_port=587)).transport_security, "starttls")
        config = validate_configuration(_payload(smtp_port=2465, smtp_security="ssl"))
        self.assertEqual(config.transport_security, "ssl")
        self.assertEqual(config.public_dict()["smtp_security"], "ssl")

    def test_legacy_settings_use_auto_and_explicit_mode_persists(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "alerts.json"
            path.write_text(json.dumps(_payload()), encoding="utf-8")
            store = AlertSettingsStore(path)
            self.assertEqual(store.configuration().smtp_security, "auto")
            store.save(_payload(smtp_port=2465, smtp_security="ssl"))
            reloaded = AlertSettingsStore(path)
            self.assertEqual(reloaded.configuration().transport_security, "ssl")
            self.assertNotIn("abcdefghijklmnop", path.read_text(encoding="utf-8"))
            self.assertNotIn("abcdefghijklmnop", json.dumps(reloaded.public_values()))

    def test_automatic_alerts_use_starttls_and_keep_filtering_and_cooldown(self):
        completed = threading.Event()
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alerts.json")
            store.save(_payload(smtp_port=587))
            self.explicit.return_value.send_message.side_effect = lambda _msg: completed.set() or {}
            service = EmailAlertService(store)
            try:
                self.assertEqual(service.submit([_record(2), _record(6)]), 1)
                self.assertEqual(service.submit([_record(2)]), 0)
                self.assertTrue(completed.wait(2))
            finally:
                service.shutdown()
            self.implicit.assert_not_called()
            self.explicit.return_value.starttls.assert_called_once()
            self.explicit.return_value.send_message.assert_called_once()

    def test_failed_automatic_alert_reports_the_stage_without_credentials(self):
        completed = threading.Event()
        errors = []
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alerts.json")
            store.save(_payload(smtp_port=587))
            self.explicit.return_value.login.side_effect = smtplib.SMTPAuthenticationError(
                535, b"abcdefghijklmnop"
            )
            def error(message):
                errors.append(message)
                completed.set()
            service = EmailAlertService(store, on_error=error)
            try:
                self.assertEqual(service.submit([_record(2)], "vi"), 1)
                self.assertTrue(completed.wait(2))
            finally:
                service.shutdown()
            self.assertIn("smtp.gmail.com:587", errors[0])
            self.assertIn("đăng nhập", errors[0])
            self.assertIn("535", errors[0])
            self.assertNotIn("abcdefghijklmnop", errors[0])
            self.explicit.return_value.send_message.assert_not_called()


if __name__ == "__main__":
    unittest.main()
