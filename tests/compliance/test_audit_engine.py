"""Unit tests for the Security Compliance Audit engine and service."""

from __future__ import annotations

import unittest

from features.compliance.engine import CiscoConfigAuditor, ParsedConfig
from features.compliance.models import AuditStatus
from features.compliance.service import SecurityComplianceService


INSECURE_ROUTER_CONFIG = """!
version 15.9
service timestamps debug datetime
service timestamps log datetime
no service password-encryption
!
hostname R1
!
enable password cisco
!
no ip domain lookup
ip source-route
ip http server
!
username admin password cisco
!
interface GigabitEthernet0/0
 ip address 192.168.122.101 255.255.255.0
 duplex auto
 speed auto
!
line con 0
 exec-timeout 0 0
 logging synchronous
line vty 0 4
 transport input all
!
end
"""

SECURE_ROUTER_CONFIG = """!
version 15.9
service timestamps debug datetime msec
service timestamps log datetime msec
service sequence-numbers
service password-encryption
!
hostname R1-SECURE
!
enable secret 5 $1$mERr$hx5rVt7rPNoS4wqbXKX7m0
!
no ip domain lookup
no ip source-route
no ip http server
!
banner motd # CANH BAO: Chi nhan vien duoc phep moi vao! #
!
username secadmin privilege 15 secret 5 $1$mERr$hx5rVt7rPNoS4wqbXKX7m0
!
access-list 10 permit 192.168.122.0 0.0.0.255
!
logging host 192.168.122.1 transport udp port 5514
logging trap notifications
logging source-interface GigabitEthernet0/0
!
interface GigabitEthernet0/0
 ip address 192.168.122.101 255.255.255.0
 no ip proxy-arp
!
line con 0
 exec-timeout 5 0
 login local
line vty 0 4
 access-class 10 in
 exec-timeout 5 0
 login local
 transport input ssh
line vty 5 15
 access-class 10 in
 exec-timeout 5 0
 login local
 transport input ssh
!
end
"""

INSECURE_SWITCH_CONFIG = """!
hostname SW1
!
enable password cisco
no service password-encryption
!
interface GigabitEthernet0/1
 switchport mode access
 switchport access vlan 10
!
interface GigabitEthernet0/2
 switchport mode trunk
!
line con 0
line vty 0 4
 transport input telnet
!
end
"""

SECURE_SWITCH_CONFIG = """!
service timestamps log datetime msec
service sequence-numbers
service password-encryption
!
hostname SW1-SECURE
!
enable secret 5 $1$mERr$hx5rVt7rPNoS4wqbXKX7m0
no ip http server
no ip source-route
!
username admin secret 5 $1$mERr$hx5rVt7rPNoS4wqbXKX7m0
!
ip dhcp snooping
ip dhcp snooping vlan 10,20
!
logging host 192.168.122.1 transport udp port 5514
!
interface GigabitEthernet0/1
 switchport mode access
 switchport access vlan 10
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation shutdown
!
interface GigabitEthernet0/2
 switchport mode trunk
 ip dhcp snooping trust
!
line con 0
 login local
 exec-timeout 5 0
line vty 0 4
 login local
 transport input ssh
 access-class 10 in
 exec-timeout 5 0
!
end
"""


class TestConfigAuditor(unittest.TestCase):
    def setUp(self) -> None:
        self.auditor = CiscoConfigAuditor()

    def test_parsed_config_blocks(self) -> None:
        p = ParsedConfig(SECURE_ROUTER_CONFIG)
        self.assertIn("GigabitEthernet0/0", p.interfaces)
        self.assertIn("line con 0", p.lines_con)
        self.assertIn("line vty 0 4", p.lines_vty)
        self.assertTrue(len(p.global_lines) > 5)
        self.assertTrue(len(p.banners) > 0)

    def test_insecure_router_audit(self) -> None:
        report = self.auditor.audit(INSECURE_ROUTER_CONFIG, host="192.168.122.101", device_name="R1", role="rou")
        self.assertEqual(report.host, "192.168.122.101")
        self.assertEqual(report.device_name, "R1")
        self.assertLess(report.score, 50)
        self.assertIn(report.grade, ("D", "F"))
        self.assertGreater(report.failed_count, 5)

        results_by_id = {r.rule_id: r for r in report.results}
        self.assertEqual(results_by_id["AUTH-01"].status, AuditStatus.FAIL.value)
        self.assertEqual(results_by_id["AUTH-02"].status, AuditStatus.FAIL.value)
        self.assertEqual(results_by_id["AUTH-03"].status, AuditStatus.FAIL.value)
        self.assertEqual(results_by_id["MGMT-01"].status, AuditStatus.FAIL.value)
        self.assertEqual(results_by_id["LOG-01"].status, AuditStatus.FAIL.value)

    def test_secure_router_audit(self) -> None:
        report = self.auditor.audit(SECURE_ROUTER_CONFIG, host="192.168.122.101", device_name="R1-SECURE", role="rou")
        self.assertGreaterEqual(report.score, 90)
        self.assertEqual(report.grade, "A")
        self.assertEqual(report.failed_count, 0)

        results_by_id = {r.rule_id: r for r in report.results}
        self.assertEqual(results_by_id["AUTH-01"].status, AuditStatus.PASS.value)
        self.assertEqual(results_by_id["AUTH-02"].status, AuditStatus.PASS.value)
        self.assertEqual(results_by_id["AUTH-03"].status, AuditStatus.PASS.value)
        self.assertEqual(results_by_id["MGMT-01"].status, AuditStatus.PASS.value)
        self.assertEqual(results_by_id["MGMT-02"].status, AuditStatus.PASS.value)
        self.assertEqual(results_by_id["LOG-01"].status, AuditStatus.PASS.value)

    def test_switch_specific_rules(self) -> None:
        insecure_sw = self.auditor.audit(INSECURE_SWITCH_CONFIG, host="192.168.122.102", device_name="SW1", role="sw2")
        results_insecure = {r.rule_id: r for r in insecure_sw.results}
        self.assertIn("L2-01", results_insecure)
        self.assertIn("L2-02", results_insecure)
        self.assertEqual(results_insecure["L2-01"].status, AuditStatus.FAIL.value)
        self.assertEqual(results_insecure["L2-02"].status, AuditStatus.FAIL.value)

        secure_sw = self.auditor.audit(SECURE_SWITCH_CONFIG, host="192.168.122.102", device_name="SW1-SECURE", role="sw2")
        results_secure = {r.rule_id: r for r in secure_sw.results}
        self.assertEqual(results_secure["L2-01"].status, AuditStatus.PASS.value)
        self.assertEqual(results_secure["L2-02"].status, AuditStatus.PASS.value)
        self.assertGreaterEqual(secure_sw.score, 85)

    def test_markdown_report_export(self) -> None:
        r1 = self.auditor.audit(SECURE_ROUTER_CONFIG, host="10.0.0.1", device_name="R1", role="rou")
        r2 = self.auditor.audit(INSECURE_ROUTER_CONFIG, host="10.0.0.2", device_name="R2", role="rou")

        service = SecurityComplianceService(db_path_getter=lambda: None)
        from features.compliance.models import NetworkAuditSummary
        summary = NetworkAuditSummary(
            average_score=(r1.score + r2.score) / 2,
            overall_grade="C",
            total_devices=2,
            healthy_devices=1,
            warning_devices=0,
            critical_devices=1,
            total_critical_fails=2,
            total_high_fails=3,
            device_reports=[r1, r2],
        )

        md = service.export_markdown(summary)
        self.assertIn("BÁO CÁO KIỂM ĐỊNH TUÂN THỦ AN NINH CẤU HÌNH", md)
        self.assertIn("R1", md)
        self.assertIn("R2", md)
        self.assertIn("Câu lệnh Cisco IOS khắc phục khuyến nghị", md)


if __name__ == "__main__":
    unittest.main()


class TestSecurityAuditController(unittest.TestCase):
    def test_controller_initial_state(self) -> None:
        service = SecurityComplianceService(db_path_getter=lambda: None)
        from features.compliance.controller import SecurityAuditController
        controller = SecurityAuditController(service)
        self.assertFalse(controller.isAuditing)
        self.assertEqual(controller.averageScore, 0.0)
        self.assertEqual(controller.overallGrade, "--")
        self.assertEqual(controller.totalDevices, 0)
        self.assertEqual(controller.deviceReports, [])
        self.assertEqual(controller.selectedReport, {})
        controller.shutdown()
