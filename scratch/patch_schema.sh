sed -i '/conn.execute(/!b; /"CREATE UNIQUE INDEX IF NOT EXISTS ux_t06_svi_host_vlan "/i\
            if table_exists("t06_dhcp_trust_ports"):\n                dhcp_cols = columns("t06_dhcp_trust_ports")\n                if "trust_dhcp" not in dhcp_cols:\n                    conn.execute("ALTER TABLE t06_dhcp_trust_ports ADD COLUMN trust_dhcp INTEGER NOT NULL DEFAULT 1;")\n                if "trust_arp" not in dhcp_cols:\n                    conn.execute("ALTER TABLE t06_dhcp_trust_ports ADD COLUMN trust_arp INTEGER NOT NULL DEFAULT 1;")\n
' /data/Projects/CAMS_2/features/switching/schema.py
