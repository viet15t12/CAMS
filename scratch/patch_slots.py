with open("/data/Projects/CAMS_2/core/switch_slots.py", "r") as f:
    text = f.read()

text = text.replace(
    "@pyqtSlot(str, str, result=\"QVariant\")\n    def addSwitchL2TrustPort(self, host: str, if_name: str) -> dict[str, Any]:\n        return add_l2_trust_port(self, host, if_name)",
    "@pyqtSlot(str, str, bool, bool, result=\"QVariant\")\n    def addSwitchL2TrustPort(self, host: str, if_name: str, trust_dhcp: bool = True, trust_arp: bool = True) -> dict[str, Any]:\n        return add_l2_trust_port(self, host, if_name, trust_dhcp, trust_arp)"
)

with open("/data/Projects/CAMS_2/core/switch_slots.py", "w") as f:
    f.write(text)
