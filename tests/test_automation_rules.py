from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from features.automation.rules import (
    RuleFileRepository,
    decode_rule_text,
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
            self.assertEqual(len(rules), 1)
            self.assertFalse(rules[0]["enabled"])
            self.assertTrue(enabled["ok"])
            self.assertTrue(repository.list_rules()[0]["enabled"])
            self.assertTrue(repository.delete_rule("mitigate-icmp-dos")["ok"])
            self.assertEqual(repository.list_rules(), [])

    def test_rejects_arbitrary_restconf_payload_and_path_traversal(self) -> None:
        value = json.loads(sample_icmp_rule_text())
        value["action"] = {
            "type": "restconf.raw",
            "url": "https://router/restconf/data",
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
