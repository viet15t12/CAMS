import unittest
import tempfile
from pathlib import Path

from PyQt6.QtCore import Q_ARG, QMetaObject, QObject, QUrl, pyqtSignal, pyqtSlot
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent, QQmlEngine, QQmlExpression
from PyQt6.QtWidgets import QApplication

from features.syslog.qt.manager import _variant_dict
from features.syslog.settings import SyslogSettings


APP_DIR = Path(__file__).resolve().parents[2]


class _DeviceConfigBackend(QObject):
    def __init__(self) -> None:
        super().__init__()
        self.deleted_payload = None

    @pyqtSlot(str, result="QVariant")
    def getDeviceConfigurations(self, host: str):
        return [{
            "device_host": host,
            "server_ip": "192.168.122.1",
            "protocol": "udp",
            "port": 5514,
            "source_interface": "GigabitEthernet0/0",
            "trap_severity": 4,
            "timestamps": False,
            "sequence_numbers": False,
            "configured": True,
            "sync_status": "synchronized",
        }]

    @pyqtSlot(str, "QVariant", result="QVariant")
    def deleteDeviceConfiguration(self, host: str, payload):
        self.deleted_payload = _variant_dict(payload)
        return {"ok": True, "message": "staged"}


class _InterfaceInventoryBackend(QObject):
    runningConfigUpdated = pyqtSignal(str)

    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, _host: str):
        return [
            {"interface_name": "Loopback0"},
            {"interface_name": "GigabitEthernet0/0"},
        ]

    @pyqtSlot(str, result="QVariant")
    def getSwitchInterfaces(self, _host: str):
        return [{"if_name": "GigabitEthernet0/1"}]

    @pyqtSlot(str, result="QVariant")
    def getSwitchSvis(self, _host: str):
        return [{"vlan_id": 10}]

    @pyqtSlot(str, result="QVariant")
    def getSwitchEtherChannels(self, _host: str):
        return [{"po_number": 1}]

    @pyqtSlot(str, str, str, result=bool)
    def hasPendingViewPush(self, _controller: str, _host: str, _module: str):
        return False


class _SecurityPolicyBackend(QObject):
    runningConfigUpdated = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.policy = {"id": 1, "vlan_id": 10, "vlan_name": "LAB",
                       "dhcp_snooping": True, "dai_enabled": True,
                       "dai_log_mode": "deny", "success": "pending_apply"}
        self.saved_payload = None

    @pyqtSlot(str, result="QVariant")
    def getSwitchL2Security(self, _host):
        return {"vlans": [self.policy], "trust_ports": [], "static_macs": [],
                "interfaces": [], "global_config": {"dhcp_option_82": "insert"}}

    @pyqtSlot(str, "QVariant", result="QVariant")
    def saveSwitchL2VlanSecurity(self, _host, payload):
        self.saved_payload = _variant_dict(payload)
        self.policy = dict(self.saved_payload)
        return {"ok": True, "message": "saved"}

    @pyqtSlot(str, str, str, result=bool)
    def hasPendingViewPush(self, _controller, _host, _module):
        return False


class SyslogQmlTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def _create(
        self, relative_path: str, context: dict | None = None,
        properties: dict | None = None,
    ):
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(APP_DIR))
        for name, value in (context or {}).items():
            engine.rootContext().setContextProperty(name, value)
        warnings: list[str] = []
        engine.warnings.connect(
            lambda rows: warnings.extend(row.toString() for row in rows)
        )
        component = QQmlComponent(
            engine,
            QUrl.fromLocalFile(str(APP_DIR / relative_path)),
        )
        instance = component.createWithInitialProperties(properties or {})
        self.app.processEvents()
        self.assertIsNotNone(
            instance,
            [error.toString() for error in component.errors()],
        )
        return engine, instance, warnings

    def test_syslog_table_renders_list_model_without_warnings(self) -> None:
        engine, instance, warnings = self._create(
            "tests/qml/SyslogTableHarness.qml"
        )
        try:
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_dai_logging_choice_survives_save_and_reload(self) -> None:
        backend = _SecurityPolicyBackend()
        engine, page, warnings = self._create(
            "UI/qml/features/switching/security/L2SecurityPage.qml",
            context={"dbManager": backend},
            properties={"host": "switch-1", "width": 1200, "height": 900},
        )
        try:
            combo = page.findChild(QObject, "l2DaiLogModeCombo")
            self.assertIsNotNone(combo)
            self.assertEqual(combo.property("currentIndex"), 0)
            combo.setProperty("currentIndex", 1)
            QMetaObject.invokeMethod(combo, "activated", Q_ARG(int, 1))
            QMetaObject.invokeMethod(page, "savePolicy")
            self.app.processEvents()
            self.assertEqual(backend.saved_payload["dai_log_mode"], "all")
            self.assertEqual(combo.property("currentIndex"), 1)
            self.assertFalse(page.property("policyDirty"))
            page.setProperty("width", 760)
            self.app.processEvents()
            self.assertTrue(page.property("compactLayout"))
            self.assertEqual(warnings, [])
        finally:
            page.deleteLater()
            engine.deleteLater()

    def test_dai_permit_outcome_is_visible_in_message_details(self) -> None:
        engine, instance, warnings = self._create("tests/qml/SyslogTableHarness.qml")
        try:
            QMetaObject.invokeMethod(instance, "showDaiPermit")
            self.app.processEvents()
            outcome = instance.findChild(QObject, "syslogSecurityOutcome")
            self.assertEqual(outcome.property("text"), "Permitted")
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_parameter_help_button_opens_explanation_dialog(self) -> None:
        engine, instance, warnings = self._create(
            "tests/qml/ParameterHelpHarness.qml"
        )
        try:
            button = instance.findChild(QObject, "parameterHelpIconButton")
            dialog = instance.findChild(QObject, "parameterHelpDialog")
            self.assertIsNotNone(button)
            self.assertIsNotNone(dialog)

            QMetaObject.invokeMethod(button, "click")
            self.app.processEvents()

            self.assertTrue(dialog.property("opened"))
            self.assertEqual(dialog.property("title"), "Destination parameters")
            self.assertEqual(warnings, [])
        finally:
            instance.close()
            instance.deleteLater()
            engine.deleteLater()

    def test_syslog_table_recycles_rows_without_null_model_warnings(self) -> None:
        engine, instance, warnings = self._create(
            "tests/qml/SyslogTableHarness.qml"
        )
        try:
            QMetaObject.invokeMethod(instance, "churnRows")
            QMetaObject.invokeMethod(instance, "exerciseNullRow")
            for _ in range(4):
                self.app.processEvents()
            relevant = [
                item for item in warnings
                if "SyslogLogRow.qml" in item
                or "SyslogMessageDetails.qml" in item
                or "undefined member" in item
                or "Cannot read property" in item
            ]
            self.assertEqual(relevant, [], warnings)
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_syslog_device_item_combines_name_and_host(self) -> None:
        cases = (
            ({"host": "192.168.122.10", "device_name": "Core-R1"},
             "Core-R1(192.168.122.10)"),
            ({"host": "192.168.122.11", "device_name": "   "},
             "192.168.122.11"),
        )
        for device_data, expected in cases:
            with self.subTest(device_data=device_data):
                engine, instance, warnings = self._create(
                    "UI/qml/sidebar/syslog/SyslogDeviceItem.qml",
                    properties={"deviceData": device_data},
                )
                try:
                    self.assertEqual(instance.property("displayLabel"), expected)
                    self.assertEqual(warnings, [])
                finally:
                    instance.deleteLater()
                    engine.deleteLater()

    def test_syslog_settings_spinboxes_do_not_create_binding_loops(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        settings = SyslogSettings(settings_path=Path(temporary.name) / "syslog.json")
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogServerSettings.qml",
            {"syslogSettings": settings, "syslogManager": None},
        )
        try:
            self.assertEqual(
                len(instance.findChildren(QObject, "parameterHelpIconButton")), 5
            )
            self.assertFalse(
                any("Binding loop" in warning for warning in warnings),
                warnings,
            )
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_device_config_delete_sends_plain_mapping_to_backend(self) -> None:
        backend = _DeviceConfigBackend()
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogDeviceConfigPage.qml",
            {"syslogManager": backend, "dbManager": None},
            {"host": "192.168.122.102"},
        )
        try:
            self.assertEqual(instance.property("selectedIndex"), 0)
            self.assertIsNotNone(instance.findChild(QObject, "syslogGroupButton"))
            self.assertGreaterEqual(
                len(instance.findChildren(QObject, "parameterHelpIconButton")), 2
            )
            QMetaObject.invokeMethod(instance, "deleteSelected")
            self.app.processEvents()
            self.assertIsInstance(backend.deleted_payload, dict)
            self.assertEqual(backend.deleted_payload["server_ip"], "192.168.122.1")
            self.assertEqual(backend.deleted_payload["port"], 5514)
            self.assertFalse(any("Syslog data must" in item for item in warnings), warnings)
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_device_config_source_interface_uses_inventory_combo_box(self) -> None:
        backend = _DeviceConfigBackend()
        inventory = _InterfaceInventoryBackend()
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogDeviceConfigPage.qml",
            {"syslogManager": backend, "dbManager": inventory},
            {"host": "192.168.122.102"},
        )
        try:
            self.assertEqual(
                instance.property("sourceInterfaceOptions").toVariant(),
                [
                    "GigabitEthernet0/0",
                    "GigabitEthernet0/1",
                    "Loopback0",
                    "Port-channel1",
                    "Vlan10",
                ],
            )
            combo = instance.findChild(QObject, "syslogSourceInterfaceCombo")
            self.assertIsNotNone(combo)
            QMetaObject.invokeMethod(instance, "beginEdit")
            self.app.processEvents()
            self.assertEqual(combo.property("currentText"), "GigabitEthernet0/0")
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_syslog_group_builds_per_host_targets_with_shared_policy(self) -> None:
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogGroupDialog.qml",
            {"dbManager": None},
        )
        try:
            self.assertEqual(
                len(instance.findChildren(QObject, "parameterHelpIconButton")), 3
            )
            result, is_undefined = QQmlExpression(
                QQmlEngine.contextForObject(instance),
                instance,
                """
                populateOptions({
                    defaults: {
                        server_ip: "198.51.100.10", protocol: "udp", port: 5514,
                        trap_severity: 5, timestamps: true, sequence_numbers: true
                    },
                    hosts: [{
                        host: "192.0.2.1", device_name: "R1", role: "rou",
                        interfaces: [{name: "Loopback0", kind: "router"}],
                        recommended_interface: "Loopback0"
                    }, {
                        host: "192.0.2.2", device_name: "R2", role: "rou",
                        interfaces: [{name: "GigabitEthernet0/0", kind: "router"}],
                        recommended_interface: "GigabitEthernet0/0"
                    }]
                });
                updateSelected(0, true);
                updateSelected(1, true);
                stepIndex = 1;
                ({valid: stepValid(), targets: selectedTargets(), policy: commonPolicy()})
                """,
            ).evaluate()

            self.assertFalse(is_undefined)
            value = result.toVariant()
            self.assertTrue(value["valid"], value)
            self.assertEqual(
                value["targets"],
                [
                    {"host": "192.0.2.1", "source_interface": "Loopback0"},
                    {"host": "192.0.2.2", "source_interface": "GigabitEthernet0/0"},
                ],
            )
            self.assertEqual(value["policy"]["server_ip"], "198.51.100.10")
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_syslog_filter_supports_multiple_hosts_and_severities(self) -> None:
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogFilterBar.qml",
            {"syslogManager": None},
            {"hostOptions": ["r1", "r2", "r3"]},
        )
        try:
            self.assertEqual(
                len(instance.findChildren(QObject, "parameterHelpIconButton")), 3
            )
            result, is_undefined = QQmlExpression(
                QQmlEngine.contextForObject(instance),
                instance,
                """
                selectedHosts = ["r1", "r3"];
                selectedSeverities = [2, 3, 4];
                currentFilters()
                """,
            ).evaluate()

            self.assertFalse(is_undefined)
            filters = result.toVariant()
            self.assertEqual(filters["hosts"], ["r1", "r3"])
            self.assertEqual(filters["host"], "")
            self.assertEqual(filters["severities"], [2, 3, 4])
            security_filter = instance.findChild(QObject, "syslogSecurityFilter")
            security_filter.setProperty("currentIndex", 4)
            result, _ = QQmlExpression(QQmlEngine.contextForObject(instance), instance, "currentFilters()").evaluate()
            self.assertEqual(result.toVariant()["security"], "port_security")
            host_filter = instance.findChild(QObject, "syslogHostFilterChip")
            severity_filter = instance.findChild(QObject, "syslogSeverityFilter")
            self.assertEqual(host_filter.property("summaryText"), "2 hosts selected")
            self.assertEqual(
                severity_filter.property("summaryText"), "3 severities selected"
            )
            QQmlExpression(QQmlEngine.contextForObject(instance), instance, "selectedHosts = []; selectedSeverities = []").evaluate()
            reset = instance.findChild(QObject, "syslogResetFiltersButton")
            self.assertTrue(reset.property("enabled"))
            QQmlExpression(QQmlEngine.contextForObject(instance), instance, "resetFilters()").evaluate()
            self.assertEqual(security_filter.property("currentIndex"), 0)
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_security_filter_applies_to_live_workspace_rows(self) -> None:
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogWorkspace.qml", {"syslogManager": None}
        )
        try:
            result, undefined = QQmlExpression(
                QQmlEngine.contextForObject(instance), instance,
                """
                activeFilters = {security: 'dai'};
                var row = normalizedLogRow({security_feature: 'dai', security_label: 'Dynamic ARP Inspection'});
                var exact = matchesFilters(row) && !matchesFilters({security_feature: 'acl'});
                activeFilters = {security: 'all'};
                exact && row.security_label === 'Dynamic ARP Inspection'
                    && matchesFilters(row) && !matchesFilters({})
                """,
            ).evaluate()
            self.assertFalse(undefined)
            self.assertTrue(result)
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_smart_filter_builder_round_trips_structured_expression(self) -> None:
        engine, instance, warnings = self._create(
            "UI/qml/features/syslog/SyslogSmartFilterBuilder.qml"
        )
        try:
            result, is_undefined = QQmlExpression(
                QQmlEngine.contextForObject(instance),
                instance,
                """
                loadExpression('host:r1,r2 severity:error,warning protocol:udp '
                               + 'since:30m last:20 facility:LINK '
                               + 'mnemonic:UPDOWN security:dai text:"changed state"');
                buildExpression()
                """,
            ).evaluate()

            self.assertFalse(is_undefined)
            expression = str(result)
            self.assertIn("host:r1,r2", expression)
            self.assertIn("severity:error,warning", expression)
            self.assertIn("protocol:udp", expression)
            self.assertIn("since:30m", expression)
            self.assertIn("security:dai", expression)
            self.assertIn('text:"changed state"', expression)
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()


if __name__ == "__main__":
    unittest.main()
