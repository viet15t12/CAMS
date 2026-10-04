with open("/data/Projects/CAMS_2/infrastructure/database/schemas/device_network/06_l2_switching.sql", "r") as f:
    text = f.read()

old_sql = """CREATE TABLE IF NOT EXISTS t06_dhcp_trust_ports (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    host     TEXT    NOT NULL REFERENCES t01_devices(host) ON DELETE CASCADE,
    if_name  TEXT    NOT NULL,
    success  TEXT    NOT NULL DEFAULT 'pending_apply'
                     CHECK(success IN ('pending_apply','pending_delete','synchronized','skipped')),
    UNIQUE(host, if_name)
);"""

new_sql = """CREATE TABLE IF NOT EXISTS t06_dhcp_trust_ports (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    host     TEXT    NOT NULL REFERENCES t01_devices(host) ON DELETE CASCADE,
    if_name  TEXT    NOT NULL,
    success  TEXT    NOT NULL DEFAULT 'pending_apply'
                     CHECK(success IN ('pending_apply','pending_delete','synchronized','skipped')),
    trust_dhcp INTEGER NOT NULL DEFAULT 1 CHECK(trust_dhcp IN (0,1)),
    trust_arp  INTEGER NOT NULL DEFAULT 1 CHECK(trust_arp IN (0,1)),
    UNIQUE(host, if_name)
);"""

if old_sql in text:
    text = text.replace(old_sql, new_sql)
else:
    print("Could not find SQL block in schema file.")

with open("/data/Projects/CAMS_2/infrastructure/database/schemas/device_network/06_l2_switching.sql", "w") as f:
    f.write(text)

with open("/data/Projects/CAMS_2/archive/backend/sql/06_l2_switching.sql", "r") as f:
    text2 = f.read()
if old_sql in text2:
    with open("/data/Projects/CAMS_2/archive/backend/sql/06_l2_switching.sql", "w") as f:
        f.write(text2.replace(old_sql, new_sql))
        
with open("/data/Projects/CAMS_2/archive/backend/PyCode/share/database/device_network/06_l2_switching.sql", "r") as f:
    text3 = f.read()
if old_sql in text3:
    with open("/data/Projects/CAMS_2/archive/backend/PyCode/share/database/device_network/06_l2_switching.sql", "w") as f:
        f.write(text3.replace(old_sql, new_sql))
print("Patched SQL schemas")
