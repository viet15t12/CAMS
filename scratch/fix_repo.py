with open("/data/Projects/CAMS_2/features/switching/security_repository.py", "r") as f:
    text = f.read()

# Fix save_l2_security_vlan
text = text.replace("""                        dai_enabled = excluded.dai_enabled,
                        success = 'pending_apply', trust_dhcp = excluded.trust_dhcp, trust_arp = excluded.trust_arp;""",
"""                        dai_enabled = excluded.dai_enabled,
                        success = 'pending_apply';""")

# Fix save_l2_security_global
text = text.replace("""                        dhcp_option_82 = excluded.dhcp_option_82,
                        success = 'pending_apply', trust_dhcp = excluded.trust_dhcp, trust_arp = excluded.trust_arp;""",
"""                        dhcp_option_82 = excluded.dhcp_option_82,
                        success = 'pending_apply';""")

with open("/data/Projects/CAMS_2/features/switching/security_repository.py", "w") as f:
    f.write(text)

