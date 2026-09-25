import sqlite3
import tempfile
import unittest
from pathlib import Path

from features.switching.sync import (
    parse_dhcp_snooping,
    parse_etherchannels,
    parse_interface_status,
    parse_l2_security,
    parse_running_config_security,
    parse_trunks,
    parse_vlan_brief,
    parse_vtp_status,
    sync_switch_state,
)
from features.switching.security_repository import get_l2_security
from scripts.build_databases import build_database
from infrastructure.database.paths import DEVICE_NETWORK_SCHEMA_DIR


VLAN_OUTPUT = """VLAN Name                             Status    Ports
1    default                          active    Gi0/1
20   USERS                            active    Gi0/2
1002 fddi-default                     act/unsup
"""

INTERFACE_OUTPUT = """Port      Name               Status       Vlan       Duplex  Speed Type
Gi0/1     uplink             connected    trunk      a-full  a-1000 10/100/1000BaseTX
Gi0/2     office             notconnect   20         auto    auto   10/100/1000BaseTX
"""

VTP_OUTPUT = """VTP Version capable             : 1 to 3
VTP version running             : 2
VTP Domain Name                 : LAB
VTP Operating Mode              : Server
VTP Pruning Mode                : Enabled
"""


class SwitchSyncParserTests(unittest.TestCase):
    def test_parses_backend_show_command_contract(self):
        self.assertEqual([row["vlan_id"] for row in parse_vlan_brief(VLAN_OUTPUT)], [1, 20])
        interfaces = parse_interface_status(INTERFACE_OUTPUT)
        self.assertEqual(interfaces[0]["if_name"], "GigabitEthernet0/1")
        self.assertEqual(interfaces[0]["mode"], "trunk")
        self.assertEqual(interfaces[1]["access_vlan"], 20)
        self.assertEqual(parse_vtp_status(VTP_OUTPUT)["domain_name"], "LAB")
        channels = parse_etherchannels("1 Po1(SU) LACP Gi0/1(P) Gi0/2(P)")
        self.assertEqual(channels[0]["member_ports"], "GigabitEthernet0/1,GigabitEthernet0/2")

    def test_parses_full_port_channel_name_as_a_trunk(self):
        status = (
            "Port-channel1 bundle connected 1 a-full a-1000 EtherChannel\n"
        )
        interfaces = parse_interface_status(status)
        trunks = parse_trunks("Port-channel1 on 802.1q trunking 1")

        self.assertEqual(interfaces[0]["if_name"], "Port-channel1")
        self.assertEqual(interfaces[0]["mode"], "access")
        self.assertIn("Port-channel1", trunks)

    def test_parses_configured_allowed_vlans_from_trunk_section(self):
        output = """Port        Mode Encapsulation Status Native vlan
Po1         on   802.1q        trunking 1

Port        Vlans allowed on trunk
Po1         10,20,30-35

Port        Vlans allowed and active in management domain
Po1         10,20,30
"""

        trunks = parse_trunks(output)

        self.assertEqual(trunks["Port-channel1"]["allowed_vlans"], "10,20,30-35")

    def test_parses_dhcp_snooping_operational_output(self):
        output = """Switch DHCP snooping is enabled
DHCP snooping is configured on following VLANs:
10,20
DHCP snooping is operational on following VLANs:
10,20
DHCP snooping database/file transfer is not configured.
Authentication is disabled.
Operational option 82 support is disabled.
Filtering on untrusted mobile nodes is disabled.
Command-line option 82 insertion is enabled.
Option 82 on untrusted port is not allowed.
Verification of hwaddr: return false
Verification of giaddr: return false
DHCP snooping trust/rate is configured on the following Interfaces:

Interface                  Trusted    Allow option    Rate limit (pps)
-----------------------    -------    ------------    ----------------
GigabitEthernet0/1         yes        yes             unlimited
GigabitEthernet0/2         yes        yes             unlimited
Port-channel1              yes        yes             unlimited
"""
        parsed = parse_dhcp_snooping(output)
        self.assertEqual(parsed["dhcp_vlans"], {10, 20})
        self.assertEqual(
            parsed["trust_ports"],
            {"GigabitEthernet0/1", "GigabitEthernet0/2", "Port-channel1"},
        )

    def test_parses_running_config_security(self):
        config = """
ip dhcp snooping vlan 10,20
ip dhcp snooping
ip arp inspection vlan 10,20
!
interface GigabitEthernet0/1
 switchport mode trunk
 ip dhcp snooping trust
 ip arp inspection trust
!
interface Port-channel1
 switchport mode trunk
 ip dhcp snooping trust
!
"""
        parsed = parse_running_config_security(config)
        self.assertEqual(parsed["dhcp_vlans"], {10, 20})
        self.assertEqual(parsed["dai_vlans"], {10, 20})
        self.assertEqual(
            parsed["trust_ports"],
            {"GigabitEthernet0/1", "Port-channel1"},
        )


class SwitchSyncPersistenceTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.tempdir.name) / "device.db"
        build_database(DEVICE_NETWORK_SCHEMA_DIR, self.db_path)
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO t01_devices(host, device_name, role, device_type) VALUES (?, ?, ?, ?)",
                ("192.0.2.20", "sw1", "sw2", "switch_layer2"),
            )

    def tearDown(self):
        self.tempdir.cleanup()

    def test_initial_safe_sync_imports_vlan_interface_and_vtp_without_password(self):
        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "vlan_brief": VLAN_OUTPUT,
                "interfaces_status": INTERFACE_OUTPUT,
                "interfaces_trunk": "Gi0/1 on 802.1q trunking 1",
                "etherchannel_summary": "",
                "vtp_status": VTP_OUTPUT,
            },
        )

        self.assertEqual(result["vlans"], 2)
        self.assertEqual(result["interfaces"], 2)
        self.assertEqual(result["vtp"], 1)
        with sqlite3.connect(self.db_path) as conn:
            domain = conn.execute(
                "SELECT domain_name, password_type, password_value FROM t09_vtp_domains"
            ).fetchone()
        self.assertEqual(domain, ("LAB", "none", None))
        preview = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "vlan_brief": VLAN_OUTPUT,
                "interfaces_status": INTERFACE_OUTPUT,
                "interfaces_trunk": "Gi0/1 on 802.1q trunking 1",
                "etherchannel_summary": "",
                "vtp_status": VTP_OUTPUT,
            },
            mode="preview",
        )
        self.assertEqual(preview["conflicts"], [])

    def test_sw3_sync_imports_fhrp_from_a_synchronized_svi(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "UPDATE t01_devices SET role = 'sw3', device_type = 'sw3' "
                "WHERE host = '192.0.2.20'"
            )
            conn.execute(
                """
                INSERT INTO t06_vlan_db(
                    host, vlan_id, vlan_name, success, device_present
                ) VALUES ('192.0.2.20', 20, 'USERS', 'synchronized', 1)
                """
            )
            conn.execute(
                """
                INSERT INTO t06_svi_interface(
                    host, vlan_id, ip_address, subnet_mask,
                    shutdown, sync_status, device_present
                ) VALUES (
                    '192.0.2.20', 20, '192.0.2.2', '255.255.255.0',
                    0, 'synchronized', 1
                )
                """
            )

        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "running_config": """
interface Vlan20
 ip address 192.0.2.2 255.255.255.0
 standby version 2
 standby 20 ip 192.0.2.1
 standby 20 priority 110
 standby 20 preempt
!
"""
            },
        )

        self.assertEqual(result["fhrp_members"], 1)
        self.assertIn("fhrp", result["applied"])
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                """
                SELECT m.interface_kind, g.protocol, g.group_number,
                       g.virtual_ip, m.sync_status
                FROM t08_fhrp_members AS m
                JOIN t08_fhrp_groups AS g ON g.fhrp_id = m.fhrp_id
                WHERE m.host = '192.0.2.20'
                """
            ).fetchone()
        self.assertEqual(
            row, ("svi", "hsrp", 20, "192.0.2.1", "synchronized")
        )

    def test_preview_preserves_existing_unpushed_vlan(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO t06_vlan_db(host, vlan_id, vlan_name) VALUES (?, ?, ?)",
                ("192.0.2.20", 30, "LOCAL-DRAFT"),
            )
        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {"vlan_brief": VLAN_OUTPUT},
            mode="preview",
        )
        self.assertEqual(result["conflicts"], ["vlan"])

    def test_trunk_output_overrides_stale_port_channel_access_status(self):
        with sqlite3.connect(self.db_path) as conn:
            iface_id = conn.execute(
                """
                INSERT INTO t06_interface_l2(host, if_name, mode, success)
                VALUES (?, 'Port-channel1', 'access', 'synchronized')
                """,
                ("192.0.2.20",),
            ).lastrowid
            conn.execute(
                "INSERT INTO t06_iface_access(iface_id, access_vlan) VALUES (?, 1)",
                (iface_id,),
            )

        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "interfaces_status": (
                    "Port-channel1 bundle connected 1 a-full a-1000 EtherChannel"
                ),
                "interfaces_trunk": """Port-channel1 on 802.1q trunking 1

Port Vlans allowed on trunk
Port-channel1 10,20
""",
            },
            mode="force_device_state",
        )

        self.assertEqual(result["interfaces"], 1)
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                """
                SELECT i.mode, a.iface_id, t.native_vlan, t.encapsulation,
                       t.allowed_vlans
                FROM t06_interface_l2 AS i
                LEFT JOIN t06_iface_access AS a ON a.iface_id = i.id
                LEFT JOIN t06_iface_trunk AS t ON t.iface_id = i.id
                WHERE i.host = ? AND i.if_name = 'Port-channel1'
                """,
                ("192.0.2.20",),
            ).fetchone()
        self.assertEqual(row, ("trunk", None, 1, "dot1q", "10,20"))

    def test_etherchannel_sync_preserves_mode_and_removes_absent_channel(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT INTO t06_etherchannel(
                    host, po_number, protocol, mode, member_ports, success,
                    device_present
                ) VALUES (?, 5, 'lacp', 'passive', 'GigabitEthernet0/1',
                          'synchronized', 1);
                """,
                ("192.0.2.20",),
            )

        snapshot = {
            "interfaces_status": (
                "Gi0/1 member connected 20 a-full a-1000 10/100/1000BaseTX"
            ),
            "interfaces_trunk": "",
            "etherchannel_summary": "5 Po5(SU) LACP Gi0/1(P)",
        }
        sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="force_device_state"
        )
        with sqlite3.connect(self.db_path) as conn:
            mode = conn.execute(
                "SELECT mode FROM t06_etherchannel WHERE po_number = 5;"
            ).fetchone()[0]
        self.assertEqual(mode, "passive")

        snapshot["etherchannel_summary"] = "Number of channel-groups in use: 0"
        sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="force_device_state"
        )
        with sqlite3.connect(self.db_path) as conn:
            remaining = conn.execute(
                "SELECT COUNT(*) FROM t06_etherchannel WHERE po_number = 5;"
            ).fetchone()[0]
        self.assertEqual(remaining, 0)

    def test_vlan_sync_removes_absent_synchronized_vlan(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT INTO t06_vlan_db(
                    host, vlan_id, vlan_name, state, success, device_present
                ) VALUES (?, 20, 'USERS', 'active', 'synchronized', 1);
                """,
                ("192.0.2.20",),
            )

        snapshot = {
            "vlan_brief": "VLAN Name Status Ports\n1 default active Gi0/1\n",
        }
        sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="force_device_state"
        )
        with sqlite3.connect(self.db_path) as conn:
            remaining = conn.execute(
                "SELECT COUNT(*) FROM t06_vlan_db WHERE host = ? AND vlan_id = 20;",
                ("192.0.2.20",),
            ).fetchone()[0]
        self.assertEqual(remaining, 0)

    def test_switch_sync_imports_l2_security_and_trust_ports(self):
        snapshot = {
            "vlan_brief": "1 default active Gi0/1\n10 SALES active\n20 USERS active\n",
            "dhcp_snooping": """Switch DHCP snooping is enabled
DHCP snooping is configured on following VLANs:
10,20
DHCP snooping is operational on following VLANs:
10,20
DHCP snooping database/file transfer is not configured.
Authentication is disabled.
Operational option 82 support is disabled.
Filtering on untrusted mobile nodes is disabled.
Command-line option 82 insertion is enabled.
Option 82 on untrusted port is not allowed.
Verification of hwaddr: return false
Verification of giaddr: return false
DHCP snooping trust/rate is configured on the following Interfaces:

Interface                  Trusted    Allow option    Rate limit (pps)
-----------------------    -------    ------------    ----------------
GigabitEthernet0/1         yes        yes             unlimited
GigabitEthernet0/2         yes        yes             unlimited
Port-channel1              yes        yes             unlimited
""",
        }
        result = sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="force_device_state"
        )
        self.assertEqual(result["security_vlans"], 2)
        self.assertEqual(result["trust_ports"], 3)
        self.assertIn("security", result["applied"])

        with sqlite3.connect(self.db_path) as conn:
            sec_rows = conn.execute(
                "SELECT vlan_id, dhcp_snooping, dai_enabled, success "
                "FROM t06_security_l2 WHERE host = '192.0.2.20' ORDER BY vlan_id;"
            ).fetchall()
            trust_rows = conn.execute(
                "SELECT if_name, success FROM t06_dhcp_trust_ports "
                "WHERE host = '192.0.2.20' ORDER BY if_name;"
            ).fetchall()

        self.assertEqual(
            sec_rows,
            [(10, 1, 0, "synchronized"), (20, 1, 0, "synchronized")],
        )
        self.assertEqual(
            trust_rows,
            [
                ("GigabitEthernet0/1", "synchronized"),
                ("GigabitEthernet0/2", "synchronized"),
                ("Port-channel1", "synchronized"),
            ],
        )

        class DB:
            def __init__(self, path):
                self.path = path
            def _connect(self):
                conn = sqlite3.connect(self.path)
                conn.row_factory = sqlite3.Row
                return conn

        summary = get_l2_security(DB(self.db_path), "192.0.2.20")
        self.assertEqual(len(summary["trust_ports"]), 3)
        self.assertEqual(
            [p["if_name"] for p in summary["trust_ports"]],
            ["GigabitEthernet0/1", "GigabitEthernet0/2", "Port-channel1"],
        )
        snoop_vlans = [v["vlan_id"] for v in summary["vlans"] if v["dhcp_snooping"]]
        self.assertEqual(snoop_vlans, [10, 20])

    def test_switch_sync_preserves_pending_security_in_safe_mode(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO t06_dhcp_trust_ports(host, if_name, success) "
                "VALUES ('192.0.2.20', 'GigabitEthernet0/3', 'pending_apply');"
            )

        snapshot = {
            "dhcp_snooping": """Switch DHCP snooping is enabled
DHCP snooping is operational on following VLANs:
10
DHCP snooping trust/rate is configured on the following Interfaces:

Interface                  Trusted    Allow option    Rate limit (pps)
-----------------------    -------    ------------    ----------------
GigabitEthernet0/1         yes        yes             unlimited
""",
        }

        preview = sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="preview"
        )
        self.assertIn("security", preview["conflicts"])

        safe_result = sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="safe"
        )
        self.assertNotIn("security", safe_result["applied"])
        with sqlite3.connect(self.db_path) as conn:
            ports = [
                row[0]
                for row in conn.execute(
                    "SELECT if_name FROM t06_dhcp_trust_ports WHERE host = '192.0.2.20';"
                ).fetchall()
            ]
        self.assertEqual(ports, ["GigabitEthernet0/3"])

        force_result = sync_switch_state(
            self.db_path, "192.0.2.20", snapshot, mode="force_device_state"
        )
        self.assertIn("security", force_result["applied"])
        with sqlite3.connect(self.db_path) as conn:
            ports = [
                row[0]
                for row in conn.execute(
                    "SELECT if_name FROM t06_dhcp_trust_ports WHERE host = '192.0.2.20';"
                ).fetchall()
            ]
        self.assertEqual(ports, ["GigabitEthernet0/1"])


if __name__ == "__main__":
    unittest.main()
