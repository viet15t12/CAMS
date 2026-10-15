from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from features.automation.rules import (
    RULE_SUFFIX,
    RuleFileRepository,
    decode_rule_text,
    sample_cli_rule_text,
    sample_icmp_rule_text,
)


class AutomationRuleFileTests(unittest.TestCase):
    def test_icmp_example_is_disabled_until_explicitly_enabled(self) -> None:
        value = decode_rule_text(sample_icmp_rule_text())

        self.assertEqual(value["metadata"]["id"], "mitigate-icmp-dos")
        self.assertFalse(value["metadata"]["enabled"])
        self.assertEqual(value["match"]["attributes"], {"protocol": "icmp"})
        self.assertIn("interface", value["match"]["require_attributes"])
        self.assertEqual(value["policy"]["mode"], "dry-run")

    def test_save_list_edit_and_delete_rule_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = RuleFileRepository(Path(temporary) / "rules")

            saved = repository.save_rule_text(sample_icmp_rule_text())
            rules = repository.list_rules()
            enabled = repository.set_enabled("mitigate-icmp-dos", True)

            self.assertTrue(saved["ok"])
            self.assertEqual(saved["file_name"], f"mitigate-icmp-dos{RULE_SUFFIX}")
            self.assertEqual(len(rules), 1)
            self.assertFalse(rules[0]["enabled"])
            self.assertEqual(rules[0]["mode"], "dry-run")
            self.assertEqual(rules[0]["transport"], "internal")
            self.assertEqual(rules[0]["target"], "attributes.interface")
            self.assertEqual(rules[0]["cooldown_seconds"], 300)
            self.assertEqual(rules[0]["max_actions_per_hour"], 6)
            self.assertTrue(enabled["ok"])
            self.assertTrue(repository.list_rules()[0]["enabled"])
            self.assertTrue(repository.delete_rule("mitigate-icmp-dos")["ok"])
            self.assertEqual(repository.list_rules(), [])

    def test_fixed_interface_shutdown_rule_uses_cams_extension(self) -> None:
        source = (
            Path(__file__).resolve().parents[1]
            / "templates/automation/shutdown-gigabitethernet0-3-on-icmp-flood.rule.cams"
        )
        value = decode_rule_text(source.read_text(encoding="utf-8"))
        self.assertEqual(value["match"]["event_type"], "ICMP_FLOOD")
        self.assertEqual(value["schedule"]["interval_seconds"], 1)
        self.assertEqual(value["action"]["interface"], "GigabitEthernet0/3")
        self.assertEqual(value["action"]["transport"], "ssh")
        self.assertFalse(value["action"]["enabled"])
        self.assertEqual(value["policy"]["mode"], "auto")

        with tempfile.TemporaryDirectory() as temporary:
            repository = RuleFileRepository(temporary)
            imported = repository.import_rule(source)
            self.assertEqual(
                imported["file_name"],
                "shutdown-gi0-3-on-icmp-flood.rule.cams",
            )
            self.assertTrue((Path(temporary) / imported["file_name"]).is_file())
            listed = repository.list_rules()[0]
            self.assertEqual(listed["mode"], "auto")
            self.assertEqual(listed["transport"], "ssh")
            self.assertEqual(listed["target"], "GigabitEthernet0/3")
            self.assertFalse(listed["action_enabled"])

    def test_version_2_accepts_bounded_ssh_cli_action(self) -> None:
        value = decode_rule_text(sample_cli_rule_text())

        self.assertEqual(value["version"], 2)
        self.assertEqual(value["action"]["type"], "ssh.cli")
        self.assertEqual(value["action"]["mode"], "config")
        self.assertEqual(len(value["action"]["commands"]), 3)
        self.assertEqual(
            value["action"]["verify_commands"],
            ["show interfaces GigabitEthernet0/3"],
        )

    def test_rule_versions_keep_separate_action_contracts(self) -> None:
        version_1 = json.loads(sample_icmp_rule_text())
        version_1["action"]["commands"] = ["router ospf 1"]
        with self.assertRaisesRegex(ValueError, "unsupported field"):
            decode_rule_text(json.dumps(version_1))

        version_2 = json.loads(sample_cli_rule_text())
        version_2["action"]["commands"] = ["router ospf 1\nreload"]
        with self.assertRaisesRegex(ValueError, "one non-empty CLI line"):
            decode_rule_text(json.dumps(version_2))

        version_2["action"]["mode"] = "shell"
        version_2["action"]["commands"] = ["show clock"]
        with self.assertRaisesRegex(ValueError, "config or exec"):
            decode_rule_text(json.dumps(version_2))

    def test_documentation_demo_rules_are_valid_and_disabled(self) -> None:
        demo_directory = (
            Path(__file__).resolve().parents[1]
            / "00_report/doc-ruleCams/demo"
        )
        sources = sorted(demo_directory.glob(f"*{RULE_SUFFIX}"))

        self.assertGreaterEqual(len(sources), 4)
        for source in sources:
            with self.subTest(source=source.name):
                value = decode_rule_text(source.read_text(encoding="utf-8"))
                self.assertFalse(value["metadata"]["enabled"])

    def test_rejects_arbitrary_network_payload_and_path_traversal(self) -> None:
        value = json.loads(sample_icmp_rule_text())
        value["action"] = {
            "type": "network.raw",
            "url": "https://router.example/api/data",
            "body": {"shutdown": True},
        }
        with self.assertRaisesRegex(ValueError, "unsupported field|Unsupported action"):
            decode_rule_text(json.dumps(value))

        with tempfile.TemporaryDirectory() as temporary:
            repository = RuleFileRepository(temporary)
            with self.assertRaisesRegex(ValueError, "Invalid automation rule id"):
                repository.delete_rule("../outside")


if __name__ == "__main__":
    unittest.main()
