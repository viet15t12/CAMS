import sqlite3
import tempfile
import unittest
from pathlib import Path

from features.syslog.application.security_events import SecurityEventDetector
from features.syslog.device_config.commands import build_enable_commands
from features.syslog.parser import parse_message
from features.syslog.persistence.device_lookup_repository import DeviceLookupRepository
from features.syslog.persistence.message_repository import MessageRepository
from features.syslog.security import SECURITY_LABELS, annotate_security
from features.syslog.smart_filter import SmartFilterError, build_log_filters
from features.switching.commands import render_security


EVENTS = (
    ("acl", "%SEC-6-IPACCESSLOGP: list EDGE denied tcp 192.0.2.9(1000) -> 192.0.2.1(22), 100 packets"),
    ("dhcp_snooping", "%DHCP_SNOOPING-5-DHCP_SNOOPING_UNTRUSTED_PORT: DHCP_SNOOPING drop message on untrusted port: GigabitEthernet1/1, message type: DHCPOFFER, MAC sa: 1234.4567.abcd, vlan: 100"),
    ("port_security", "%PORT_SECURITY-2-PSECURE_VIOLATION: Security violation on interface GigabitEthernet1/1, MAC 1234.4567.abcd"),
    ("port_security", "%PM-4-ERR_DISABLE: psecure-violation error detected on Gi1/1"),
    ("dai", "%SW_DAI-4-DHCP_SNOOPING_DENY: Invalid ARP on interface GigabitEthernet1/1, MAC 1234.4567.abcd"),
    ("authentication", "%SEC_LOGIN-4-LOGIN_FAILED: Login failed from 192.0.2.9"),
    ("stp_guard", "%SPANTREE-2-BLOCK_BPDUGUARD: Received BPDU on port Gi1/1"),
    ("", "%LINK-3-UPDOWN: Interface Gi1/1, changed state to down"),
)


class SecurityMonitoringTests(unittest.TestCase):
    def test_parse_store_query_and_alert_categories_agree(self):
        with tempfile.TemporaryDirectory() as temporary:
            info_db = Path(temporary) / "info.db"
            with sqlite3.connect(info_db):
                pass
            repository = MessageRepository(info_db)
            messages = [parse_message(raw.encode(), "192.0.2.1", "udp") for _, raw in EVENTS]
            for message in messages:
                message.device_host = "switch-1"
            live = repository.insert_messages(messages)
            self.assertEqual([row["security_feature"] for row in live], [key for key, _ in EVENTS])
            self.assertEqual(live[0]["severity"], 6)
            for category in SECURITY_LABELS:
                expected = {row["id"] for row in live if row["security_feature"] == category}
                stored = repository.query_messages({"security": category})
                self.assertEqual({row["id"] for row in stored}, expected)
            self.assertEqual(len(repository.query_messages({"security": "all"})), 7)
            self.assertEqual(len(repository.query_messages({"security": "all", "severities": [6]})), 1)
            self.assertEqual(repository.query_messages({"security": "all", "host": "other"}), [])
            self.assertEqual(len(repository.query_messages({"security": "all", "per_host": 2})), 2)
            first = repository.query_messages({"security": "all"}, limit=2)
            rest = repository.query_messages({"security": "all"}, before_id=first[-1]["id"])
            self.assertEqual(len(first) + len(rest), 7)
            detector = SecurityEventDetector()
            alerts = detector.process(live)
            self.assertEqual(len(alerts), 1)
            self.assertEqual(alerts[0].mnemonic, "ACL_DROP_FLOOD")
            published = repository.insert_messages(alerts)
            self.assertEqual(published[0]["security_feature"], "security_alert")
            self.assertEqual(detector.process(published), [])
            self.assertEqual(detector.process(live), [])  # cooldown
            detector.reset()
            self.assertEqual(len(detector.process(live)), 1)
            self.assertEqual(len(repository.query_messages({"security": "security_alert"})), 1)

    def test_smart_filter_validation_and_toolbar_override(self):
        self.assertEqual(build_log_filters({"security": "all"}, "security:dhcp-snooping")["security"], "dhcp_snooping")
        with self.assertRaises(SmartFilterError):
            build_log_filters({}, "security:unknown")
        self.assertEqual(annotate_security({"facility": "ACL"})["security_feature"], "acl")

    def test_svi_source_is_attributed_to_inventory_host(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "devices.db"
            with sqlite3.connect(path) as conn:
                conn.executescript("CREATE TABLE t01_devices(host TEXT); CREATE TABLE t06_svi(host TEXT, ip_address TEXT, sync_status TEXT);")
                conn.execute("INSERT INTO t01_devices VALUES ('192.0.2.1')")
                conn.execute("INSERT INTO t06_svi VALUES ('192.0.2.1', '192.0.2.10', 'synchronized')")
                conn.execute("INSERT INTO t06_svi VALUES ('192.0.2.1', '192.0.2.11', 'pending_delete')")
            repository = DeviceLookupRepository(path)
            self.assertEqual(repository.resolve_device_host("192.0.2.10"), "192.0.2.1")
            self.assertIsNone(repository.resolve_device_host("192.0.2.11"))
            self.assertIsNone(repository.resolve_device_host("192.0.2.99"))

    def test_device_commands_enable_logging_and_keep_destination_explicit(self):
        commands = build_enable_commands("192.0.2.100", "udp", 5514, "Vlan100")
        self.assertIn("logging on", commands)
        self.assertIn("logging trap informational", commands)
        self.assertIn("logging trap emergencies", build_enable_commands("192.0.2.100", "udp", 5514, "Vlan100", 0))
        payload = {"vlans": [{"vlan_id": 100, "dhcp_snooping": True, "dai_enabled": True}], "trust_ports": [], "ports": [], "static_macs": []}
        security = render_security(payload)
        self.assertIn("no ip arp inspection vlan 100 logging dhcp-bindings", security)
        self.assertIn("no ip arp inspection vlan 100 logging acl-match", security)
        self.assertFalse(any("logging host" in command for command in security))
        payload["ports"] = [{"enabled": True, "violation": "protect"}]
        with self.assertRaisesRegex(ValueError, "without Syslog"):
            render_security(payload)

    def test_detector_memory_is_bounded_under_many_offenders(self):
        detector = SecurityEventDetector()
        detector._MAX_KEYS = 3
        detector._MAX_EVENTS_PER_KEY = 4
        rows = [{"device_host": "switch-1", "cisco_facility": "SW_DAI", "message": f"Invalid ARP on interface Gi1/{port}"} for port in range(20)]
        detector.process(rows)
        detector.process([rows[-1]] * 30)
        self.assertLessEqual(len(detector._windows), 3)
        self.assertTrue(all(len(window.hits) <= 4 for window in detector._windows.values()))
