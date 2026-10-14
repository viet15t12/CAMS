from __future__ import annotations

import os
from pathlib import Path
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlComponent, QQmlEngine


APP_DIR = Path(__file__).resolve().parents[1]
HOSTS = [
    {"host": "192.168.122.101", "name": "Switch1", "role": "sw2"},
    {"host": "192.168.122.102", "name": "Switch2", "role": "sw3"},
    {"host": "192.168.122.103", "name": "Switch3", "role": "sw2"},
    {"host": "192.168.122.104", "name": "R1", "role": "router"},
    {"host": "192.168.122.105", "name": "R2", "role": "rou"},
    {"host": "192.168.122.130", "name": "R3", "role": "router"},
]


class HostPatternTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.engine = QQmlEngine()
        cls.engine.addImportPath(str(APP_DIR))
        component = QQmlComponent(cls.engine)
        component.setData(
            b"import QtQuick\nimport UI\nQtObject {\n"
            b"    function run(items, expr) { return HostPattern.select(items, expr) }\n}\n",
            QUrl.fromLocalFile(str(APP_DIR / "host_pattern_probe.qml")),
        )
        cls.probe = component.create()
        assert cls.probe is not None, [e.toString() for e in component.errors()]

    def select(self, expression: str) -> dict:
        from PyQt6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QVariant

        result = QMetaObject.invokeMethod(
            self.probe, "run",
            Q_RETURN_ARG(QVariant), Q_ARG(QVariant, HOSTS), Q_ARG(QVariant, expression),
        )
        return result.toVariant() if hasattr(result, "toVariant") else result

    def test_all_minus_subnet_and_name_works_like_passive_default(self) -> None:
        # .100/30 covers .100-.103, so only R1 and R2 remain once R3 is excluded.
        result = self.select("all !192.168.122.100/30 !R3")
        self.assertEqual(result["error"], "")
        self.assertEqual(result["hosts"], ["192.168.122.104", "192.168.122.105"])

    def test_exclusions_alone_start_from_every_host(self) -> None:
        result = self.select("!SW*")
        self.assertEqual(
            result["hosts"], ["192.168.122.104", "192.168.122.105", "192.168.122.130"]
        )

    def test_subnet_range_and_wildcard_add_hosts(self) -> None:
        self.assertEqual(
            self.select("192.168.122.128/26")["hosts"], ["192.168.122.130"]
        )
        self.assertEqual(
            self.select("192.168.122.101-103")["hosts"],
            ["192.168.122.101", "192.168.122.102", "192.168.122.103"],
        )
        self.assertEqual(
            self.select("r? 192.168.122.101")["hosts"],
            ["192.168.122.101", "192.168.122.104", "192.168.122.105", "192.168.122.130"],
        )

    def test_device_type_keywords_select_routers_and_switch_layers(self) -> None:
        routers = ["192.168.122.104", "192.168.122.105", "192.168.122.130"]
        self.assertEqual(self.select("router")["hosts"], routers)
        self.assertEqual(
            self.select("switch")["hosts"],
            ["192.168.122.101", "192.168.122.102", "192.168.122.103"],
        )
        self.assertEqual(self.select("L3")["hosts"], ["192.168.122.102"])

    def test_name_ranges_select_by_number(self) -> None:
        self.assertEqual(
            self.select("R1-R2")["hosts"], ["192.168.122.104", "192.168.122.105"]
        )
        self.assertEqual(
            self.select("switch2-3")["hosts"], ["192.168.122.102", "192.168.122.103"]
        )
        self.assertEqual(self.select("R1-3 !R2")["hosts"], ["192.168.122.104", "192.168.122.130"])

    def test_invalid_tokens_report_an_error_instead_of_selecting(self) -> None:
        for expression in ("", "192.168.122.0/40", "300.1.1.1", "10.0.0.9-3", "R9-R2"):
            result = self.select(expression)
            self.assertNotEqual(result["error"], "", expression)
            self.assertEqual(result["hosts"], [], expression)


    def _bar(self, selected: list[str]):
        component = QQmlComponent(self.engine)
        component.setData(
            b"import QtQuick\nimport UI\nHostSelectionBar {\n"
            b"    property var emitted: []\n"
            b"    onApplySelection: hosts => emitted = hosts\n}\n",
            QUrl.fromLocalFile(str(APP_DIR / "host_selection_probe.qml")),
        )
        bar = component.create()
        assert bar is not None, [e.toString() for e in component.errors()]
        bar.setProperty("items", HOSTS)
        bar.setProperty("selectedHosts", selected)
        return bar

    def _exclude(self, bar, text: str) -> list[str]:
        from PyQt6.QtCore import QObject
        from PyQt6.QtQml import QQmlExpression

        bar.findChild(QObject, "hostPatternField").setProperty("text", text)
        QQmlExpression(self.engine.contextForObject(bar), bar, "applyPattern(true)").evaluate()
        emitted = bar.property("emitted")
        return emitted.toVariant() if hasattr(emitted, "toVariant") else list(emitted)

    def test_exclude_without_bang_drops_typed_hosts_from_everything(self) -> None:
        bar = self._bar([])
        self.assertEqual(
            self._exclude(bar, "R3 Switch1 192.168.122.102"),
            ["192.168.122.103", "192.168.122.104", "192.168.122.105"],
        )

    def test_exclude_narrows_an_existing_selection(self) -> None:
        bar = self._bar(["192.168.122.104", "192.168.122.105", "192.168.122.130"])
        self.assertEqual(self._exclude(bar, "R2"), ["192.168.122.104", "192.168.122.130"])


if __name__ == "__main__":
    unittest.main()
