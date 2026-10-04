with open("/data/Projects/CAMS_2/features/switching/security_repository.py", "r") as f:
    text = f.read()

text = text.replace(
    "WHERE host = ? AND if_name = ? AND mode <> 'routed'\n                      AND COALESCE(success, 'pending_apply') <> 'pending_delete';\n                    \",\n                    (target, interface, 1 if trust_dhcp else 0, 1 if trust_arp else 0),",
    "WHERE host = ? AND if_name = ? AND mode <> 'routed'\n                      AND COALESCE(success, 'pending_apply') <> 'pending_delete';\n                    \",\n                    (target, interface),"
)

text = text.replace(
    "\"SELECT id FROM t06_dhcp_trust_ports WHERE host = ? AND if_name = ?;\",\n                    (target, interface, 1 if trust_dhcp else 0, 1 if trust_arp else 0),",
    "\"SELECT id FROM t06_dhcp_trust_ports WHERE host = ? AND if_name = ?;\",\n                    (target, interface),"
)

with open("/data/Projects/CAMS_2/features/switching/security_repository.py", "w") as f:
    f.write(text)
