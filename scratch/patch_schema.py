with open("/data/Projects/CAMS_2/features/switching/schema.py", "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "if table_exists(\"t06_svi_interface\"):" in line:
        new_lines.append("""            if table_exists("t06_dhcp_trust_ports"):
                dhcp_cols = columns("t06_dhcp_trust_ports")
                if "trust_dhcp" not in dhcp_cols:
                    conn.execute("ALTER TABLE t06_dhcp_trust_ports ADD COLUMN trust_dhcp INTEGER NOT NULL DEFAULT 1 CHECK(trust_dhcp IN (0,1));")
                if "trust_arp" not in dhcp_cols:
                    conn.execute("ALTER TABLE t06_dhcp_trust_ports ADD COLUMN trust_arp INTEGER NOT NULL DEFAULT 1 CHECK(trust_arp IN (0,1));")
""")
    new_lines.append(line)

with open("/data/Projects/CAMS_2/features/switching/schema.py", "w") as f:
    f.writelines(new_lines)
