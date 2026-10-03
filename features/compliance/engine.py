"""Cisco IOS configuration parser and security rule evaluation engine."""

from __future__ import annotations

import re
from typing import Any

from .models import (
    AuditCategory,
    AuditRuleDefinition,
    AuditSeverity,
    AuditStatus,
    DeviceAuditReport,
    NetworkAuditSummary,
    RuleResult,
)
from .rules import ALL_RULES


class ParsedConfig:
    """Structured decomposition of a Cisco IOS running-config text."""

    def __init__(self, raw_text: str) -> None:
        self.raw_text = raw_text or ""
        self.lines: list[str] = [line.rstrip() for line in self.raw_text.splitlines()]
        self.global_lines: list[str] = []
        self.interfaces: dict[str, list[str]] = {}
        self.lines_con: dict[str, list[str]] = {}
        self.lines_vty: dict[str, list[str]] = {}
        self.banners: list[str] = []
        self._parse()

    def _parse(self) -> None:
        current_block: str | None = None
        current_lines: list[str] = []
        in_banner = False
        banner_delimiter = ""

        for line in self.lines:
            stripped = line.strip()
            if not stripped or stripped.startswith("!"):
                continue

            # Multi-line banner handling
            if in_banner:
                self.banners.append(line)
                if banner_delimiter and banner_delimiter in line:
                    in_banner = False
                continue

            if stripped.lower().startswith("banner "):
                self.banners.append(line)
                parts = stripped.split(maxsplit=2)
                if len(parts) >= 3:
                    rest = parts[2]
                    delim = rest[0] if rest else ""
                    if delim and delim in rest[1:]:
                        in_banner = False
                    else:
                        in_banner = True
                        banner_delimiter = delim
                continue

            # Block detection
            if not line.startswith(" ") and not line.startswith("\t"):
                # End previous block
                if current_block:
                    self._store_block(current_block, current_lines)
                    current_block = None
                    current_lines = []

                lower = stripped.lower()
                if lower.startswith("interface "):
                    current_block = stripped
                elif lower.startswith("line vty "):
                    current_block = stripped
                elif lower.startswith("line con "):
                    current_block = stripped
                elif lower.startswith("line aux "):
                    current_block = stripped
                else:
                    self.global_lines.append(stripped)
            else:
                if current_block:
                    current_lines.append(stripped)
                else:
                    self.global_lines.append(stripped)

        if current_block:
            self._store_block(current_block, current_lines)

    def _store_block(self, block_name: str, lines: list[str]) -> None:
        lower = block_name.lower()
        if lower.startswith("interface "):
            if_name = block_name.split(maxsplit=1)[1].strip()
            self.interfaces[if_name] = lines
        elif lower.startswith("line vty "):
            self.lines_vty[block_name] = lines
        elif lower.startswith("line con "):
            self.lines_con[block_name] = lines

    def find_globals(self, pattern: str) -> list[str]:
        regex = re.compile(pattern, re.IGNORECASE)
        return [line for line in self.global_lines if regex.search(line)]


class CiscoConfigAuditor:
    """Evaluates audit rules against a parsed Cisco IOS configuration."""

    def __init__(self, rules: tuple[AuditRuleDefinition, ...] = ALL_RULES) -> None:
        self.rules = rules

    def audit(
        self,
        config_text: str,
        host: str = "unknown",
        device_name: str = "",
        role: str = "rou",
    ) -> DeviceAuditReport:
        parsed = ParsedConfig(config_text)
        dev_name = device_name or host
        normalized_role = (role or "rou").lower()
        if normalized_role not in ("rou", "sw2", "sw3"):
            normalized_role = "rou"

        results: list[RuleResult] = []
        total_penalty = 0

        for rule in self.rules:
            # Check applicability
            if normalized_role not in rule.applicable_roles:
                continue

            evaluator_name = f"_eval_{rule.id.replace('-', '_').lower()}"
            evaluator = getattr(self, evaluator_name, None)
            if callable(evaluator):
                result = evaluator(parsed, rule, normalized_role)
            else:
                result = RuleResult(
                    rule_id=rule.id,
                    title=rule.title,
                    category=rule.category,
                    severity=rule.severity,
                    status=AuditStatus.NOT_APPLICABLE.value,
                    details="Quy tắc chưa có bộ kiểm tra.",
                )

            results.append(result)

            if result.status == AuditStatus.FAIL.value:
                total_penalty += rule.weight
            elif result.status == AuditStatus.WARNING.value:
                total_penalty += max(1, rule.weight // 2)

        score = max(0, min(100, 100 - total_penalty))
        grade = self._score_to_grade(score)
        passed = sum(1 for r in results if r.status == AuditStatus.PASS.value)
        failed = sum(1 for r in results if r.status == AuditStatus.FAIL.value)
        warnings = sum(1 for r in results if r.status == AuditStatus.WARNING.value)

        return DeviceAuditReport(
            host=host,
            device_name=dev_name,
            role=normalized_role,
            score=score,
            grade=grade,
            passed_count=passed,
            failed_count=failed,
            warnings_count=warnings,
            total_rules=len(results),
            results=results,
        )

    @staticmethod
    def _score_to_grade(score: int) -> str:
        if score >= 90:
            return "A"
        if score >= 80:
            return "B"
        if score >= 65:
            return "C"
        if score >= 50:
            return "D"
        return "F"

    # ── Rule Evaluators ────────────────────────────────────────────────────────

    def _eval_auth_01(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        secret_lines = p.find_globals(r"^enable\s+secret\b")
        pw_lines = p.find_globals(r"^enable\s+password\b")

        if secret_lines:
            matched = list(secret_lines)
            if pw_lines:
                matched.extend(pw_lines)
                return RuleResult(
                    rule.id, rule.title, rule.category, rule.severity,
                    AuditStatus.WARNING.value,
                    "Có 'enable secret' nhưng vẫn còn 'enable password' cũ chưa được xóa.",
                    matched, rule.remediation,
                )
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Mật khẩu đặc quyền đã được bảo vệ bằng 'enable secret'.",
                matched, rule.remediation,
            )

        if pw_lines:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.FAIL.value,
                "Đang sử dụng 'enable password' yếu thay vì 'enable secret'.",
                pw_lines, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            "Không tìm thấy cấu hình mật khẩu đặc quyền (enable secret/password).",
            [], rule.remediation,
        )

    def _eval_auth_02(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        enc_lines = p.find_globals(r"^service\s+password-encryption\b")
        no_enc = p.find_globals(r"^no\s+service\s+password-encryption\b")

        if enc_lines and not no_enc:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Dịch vụ mã hóa mật khẩu đã được kích hoạt.",
                enc_lines, rule.remediation,
            )
        matched = no_enc if no_enc else []
        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            "Chưa bật 'service password-encryption'. Mật khẩu có thể bị nhìn thấy trong running-config.",
            matched, rule.remediation,
        )

    def _eval_auth_03(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        user_lines = p.find_globals(r"^username\s+")
        if not user_lines:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.WARNING.value,
                "Không có tài khoản cục bộ (username) nào được khai báo.",
                [], rule.remediation,
            )

        insecure_users = [
            u for u in user_lines
            if not re.search(r"\b(secret|algorithm-type)\b", u, re.IGNORECASE)
        ]
        if insecure_users:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.FAIL.value,
                f"Phát hiện {len(insecure_users)} tài khoản dùng 'password' thô thay vì 'secret'.",
                insecure_users, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.PASS.value,
            f"Tất cả {len(user_lines)} tài khoản cục bộ đều dùng mật khẩu băm 'secret'.",
            user_lines, rule.remediation,
        )

    def _eval_auth_04(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        aaa_lines = p.find_globals(r"^aaa\s+new-model\b")
        if aaa_lines:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Hệ thống đã kích hoạt mô hình xác thực AAA (aaa new-model).",
                aaa_lines, rule.remediation,
            )

        con_missing = []
        for name, lines in p.lines_con.items():
            if not any(re.search(r"^\s*login(\s+local|\s+authentication|\b)", l) for l in lines) \
                    or any(re.search(r"^\s*no\s+login\b", l) for l in lines):
                con_missing.append(name)

        vty_missing = []
        for name, lines in p.lines_vty.items():
            if not any(re.search(r"^\s*login(\s+local|\s+authentication|\b)", l) for l in lines) \
                    or any(re.search(r"^\s*no\s+login\b", l) for l in lines):
                vty_missing.append(name)

        if not con_missing and not vty_missing and (p.lines_con or p.lines_vty):
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Các đường truyền Console và VTY đều cấu hình xác thực đăng nhập.",
                list(p.lines_con.keys()) + list(p.lines_vty.keys()), rule.remediation,
            )

        fails = con_missing + vty_missing
        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            f"Các cổng sau chưa cấu hình xác thực đăng nhập: {', '.join(fails)}.",
            fails, rule.remediation,
        )

    def _eval_mgmt_01(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        if not p.lines_vty:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.WARNING.value,
                "Không tìm thấy cấu hình line vty trong running-config.",
                [], rule.remediation,
            )

        telnet_found = []
        all_found = []
        ssh_only = []

        for name, lines in p.lines_vty.items():
            inputs = [l for l in lines if l.strip().startswith("transport input")]
            if not inputs:
                # Default Cisco behavior permits telnet
                telnet_found.append(f"{name} (mặc định không giới hạn)")
            else:
                for inp in inputs:
                    val = inp.lower()
                    if "all" in val:
                        all_found.append(f"{name}: {inp}")
                    elif "telnet" in val:
                        telnet_found.append(f"{name}: {inp}")
                    elif "ssh" in val and "telnet" not in val:
                        ssh_only.append(f"{name}: {inp}")

        if telnet_found or all_found:
            matched = telnet_found + all_found
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.FAIL.value,
                f"Phát hiện đường truyền VTY cho phép kết nối Telnet không mã hóa.",
                matched, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.PASS.value,
            "Tất cả các cổng VTY đều bắt buộc SSH và đã chặn Telnet.",
            ssh_only, rule.remediation,
        )

    def _eval_mgmt_02(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        if not p.lines_vty:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.WARNING.value,
                "Không tìm thấy cấu hình line vty.",
                [], rule.remediation,
            )

        ac_lines = []
        for name, lines in p.lines_vty.items():
            for l in lines:
                if re.search(r"^\s*access-class\s+\S+\s+in\b", l, re.IGNORECASE):
                    ac_lines.append(f"{name}: {l}")

        if ac_lines:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã cấu hình ACL giới hạn dải IP quản trị truy cập VTY.",
                ac_lines, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            "Chưa cấu hình 'access-class <ACL> in' trên các đường VTY để bảo vệ dịch vụ SSH.",
            list(p.lines_vty.keys()), rule.remediation,
        )

    def _eval_mgmt_03(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        timeouts = []
        zero_timeouts = []
        for block_dict in (p.lines_con, p.lines_vty):
            for name, lines in block_dict.items():
                for l in lines:
                    match = re.search(r"^\s*exec-timeout\s+(\d+)(?:\s+(\d+))?", l)
                    if match:
                        minutes = int(match.group(1))
                        seconds = int(match.group(2) or 0)
                        if minutes == 0 and seconds == 0:
                            zero_timeouts.append(f"{name}: {l}")
                        else:
                            timeouts.append(f"{name}: {l} ({minutes}m{seconds}s)")

        if zero_timeouts:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.FAIL.value,
                "Phát hiện cổng đang tắt timeout rảnh rỗi (exec-timeout 0 0).",
                zero_timeouts, rule.remediation,
            )

        if timeouts:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã cấu hình thời gian tự động ngắt phiên rảnh rỗi (exec-timeout).",
                timeouts, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.WARNING.value,
            "Chưa cấu hình rõ ràng exec-timeout trên Console/VTY.",
            [], rule.remediation,
        )

    def _eval_mgmt_04(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        if p.banners:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã cấu hình biểu ngữ cảnh báo pháp lý (Banner).",
                p.banners[:2], rule.remediation,
            )
        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.WARNING.value,
            "Chưa cấu hình banner cảnh báo truy cập trái phép.",
            [], rule.remediation,
        )

    def _eval_hard_01(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        http_server = p.find_globals(r"^ip\s+http\s+server\b")
        no_http = p.find_globals(r"^no\s+ip\s+http\s+server\b")

        if http_server and not no_http:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.FAIL.value,
                "Máy chủ HTTP không mã hóa đang được bật (ip http server).",
                http_server, rule.remediation,
            )

        matched = no_http if no_http else []
        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.PASS.value,
            "Máy chủ HTTP không mã hóa đã được vô hiệu hóa.",
            matched, rule.remediation,
        )

    def _eval_hard_02(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        source_route = p.find_globals(r"^ip\s+source-route\b")
        no_source_route = p.find_globals(r"^no\s+ip\s+source-route\b")

        if source_route and not no_source_route:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.FAIL.value,
                "Định tuyến nguồn IP đang được kích hoạt (ip source-route).",
                source_route, rule.remediation,
            )

        if no_source_route:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Định tuyến nguồn IP đã được tắt bằng 'no ip source-route'.",
                no_source_route, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.WARNING.value,
            "Khuyến nghị thêm lệnh tường minh 'no ip source-route'.",
            [], rule.remediation,
        )

    def _eval_hard_03(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        no_proxy = []
        for if_name, lines in p.interfaces.items():
            for l in lines:
                if re.search(r"^\s*no\s+ip\s+proxy-arp\b", l, re.IGNORECASE):
                    no_proxy.append(f"{if_name}: {l}")

        if no_proxy:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã cấu hình tắt Proxy ARP trên các giao diện.",
                no_proxy, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.WARNING.value,
            "Khuyến nghị bổ sung 'no ip proxy-arp' trên các cổng Layer 3 hướng ngoại.",
            [], rule.remediation,
        )

    def _eval_log_01(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        log_hosts = p.find_globals(r"^logging\s+(host|server)\b")
        if log_hosts:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã cấu hình chuyển tiếp nhật ký Syslog về máy chủ giám sát.",
                log_hosts, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            "Chưa cấu hình máy chủ nhận Syslog tập trung (thiếu 'logging host').",
            [], rule.remediation,
        )

    def _eval_log_02(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        msec_lines = p.find_globals(r"^service\s+timestamps\s+log\s+datetime\s+msec\b")
        if msec_lines:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã bật mốc thời gian mili-giây cho nhật ký.",
                msec_lines, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            "Chưa cấu hình 'service timestamps log datetime msec'.",
            [], rule.remediation,
        )

    def _eval_log_03(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        seq_lines = p.find_globals(r"^service\s+sequence-numbers\b")
        if seq_lines:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "Đã bật số thứ tự tuần tự cho bản tin nhật ký.",
                seq_lines, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.WARNING.value,
            "Khuyến nghị bật 'service sequence-numbers' để kiểm soát toàn vẹn luồng log.",
            [], rule.remediation,
        )

    def _eval_l2_01(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        access_ports = []
        secured_ports = []

        for if_name, lines in p.interfaces.items():
            is_access = any(
                re.search(r"^\s*switchport\s+mode\s+access\b", l, re.IGNORECASE)
                for l in lines
            )
            has_psec = any(
                re.search(r"^\s*switchport\s+port-security\b", l, re.IGNORECASE)
                for l in lines
            )
            if is_access:
                access_ports.append(if_name)
                if has_psec:
                    secured_ports.append(if_name)

        if not access_ports:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.NOT_APPLICABLE.value,
                "Không phát hiện cổng nào được cấu hình 'switchport mode access'.",
                [], rule.remediation,
            )

        if len(secured_ports) == len(access_ports):
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                f"Tất cả {len(secured_ports)} cổng Access đều đã bật Port Security.",
                [f"Interface {p}" for p in secured_ports], rule.remediation,
            )

        unsecured = [p for p in access_ports if p not in secured_ports]
        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            f"Phát hiện {len(unsecured)}/{len(access_ports)} cổng Access chưa bật Port Security: {', '.join(unsecured)}.",
            [f"Interface {p}" for p in unsecured], rule.remediation,
        )

    def _eval_l2_02(
        self, p: ParsedConfig, rule: AuditRuleDefinition, role: str
    ) -> RuleResult:
        snoop_global = p.find_globals(r"^ip\s+dhcp\s+snooping\b")
        snoop_vlan = p.find_globals(r"^ip\s+dhcp\s+snooping\s+vlan\b")

        if snoop_global and snoop_vlan:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.PASS.value,
                "DHCP Snooping đã được kích hoạt toàn cục và áp dụng cho các VLAN.",
                snoop_global + snoop_vlan, rule.remediation,
            )

        if snoop_global and not snoop_vlan:
            return RuleResult(
                rule.id, rule.title, rule.category, rule.severity,
                AuditStatus.WARNING.value,
                "Đã bật 'ip dhcp snooping' nhưng chưa chỉ định danh sách VLAN cụ thể.",
                snoop_global, rule.remediation,
            )

        return RuleResult(
            rule.id, rule.title, rule.category, rule.severity,
            AuditStatus.FAIL.value,
            "Chưa kích hoạt tính năng DHCP Snooping trên Switch.",
            [], rule.remediation,
        )
