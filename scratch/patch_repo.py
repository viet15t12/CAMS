with open("/data/Projects/CAMS_2/features/switching/security_repository.py", "r") as f:
    text = f.read()

text = text.replace(
    "SELECT id, if_name, success FROM t06_dhcp_trust_ports",
    "SELECT id, if_name, success, trust_dhcp, trust_arp FROM t06_dhcp_trust_ports"
)

text = text.replace(
    "def add_l2_trust_port(db: Any, host: str, if_name: Any) -> dict[str, Any]:",
    "def add_l2_trust_port(db: Any, host: str, if_name: Any, trust_dhcp: bool = True, trust_arp: bool = True) -> dict[str, Any]:"
)

text = text.replace(
    "INSERT INTO t06_dhcp_trust_ports(host, if_name, success)",
    "INSERT INTO t06_dhcp_trust_ports(host, if_name, success, trust_dhcp, trust_arp)"
)

text = text.replace(
    "VALUES (?, ?, 'pending_apply')",
    "VALUES (?, ?, 'pending_apply', ?, ?)"
)

text = text.replace(
    "success = 'pending_apply';",
    "success = 'pending_apply', trust_dhcp = excluded.trust_dhcp, trust_arp = excluded.trust_arp;"
)

text = text.replace(
    "(target, interface),",
    "(target, interface, 1 if trust_dhcp else 0, 1 if trust_arp else 0),"
)

with open("/data/Projects/CAMS_2/features/switching/security_repository.py", "w") as f:
    f.write(text)
