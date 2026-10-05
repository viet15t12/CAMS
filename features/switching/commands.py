from __future__ import annotations

from typing import Any

from .interface_commands import render_interfaces
from .security_logging import dai_log_mode


def _interface_header(name: str) -> list[str]:
    return [f"interface {name}"]


def render_vlan(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    for vlan in payload["vlans"]:
        if vlan.get("action") == "remove":
            commands.append(f"no vlan {vlan['vlan_id']}")
            continue
        commands.append(f"vlan {vlan['vlan_id']}")
        if vlan["vlan_name"]:
            commands.append(f" name {vlan['vlan_name']}")
        commands.append(f" state {vlan['state']}")
        commands.append(" exit")
    return commands


def render_svi(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    if "ip_routing" in payload:
        commands.append("ip routing" if payload["ip_routing"] else "no ip routing")
    for item in payload.get("svis", []):
        vlan_id = int(item["vlan_id"])
        if item.get("action") == "remove":
            commands.append(f"no interface Vlan{vlan_id}")
            continue
        commands.append(f"interface Vlan{vlan_id}")
        if item.get("ip_address"):
            if str(item.get("ip_address")).lower() == "dhcp":
                commands.append(" ip address dhcp")
            elif item.get("subnet_mask"):
                commands.append(f" ip address {item['ip_address']} {item['subnet_mask']}")
            else:
                commands.append(" no ip address")
        else:
            commands.append(" no ip address")
        commands.append(" shutdown" if item.get("shutdown") else " no shutdown")
        commands.append(" exit")
    return commands


def render_stp(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    global_rows = payload["global"]
    active_rows = [row for row in global_rows if row.get("action") != "remove"]
    if any(row.get("stp_mode") == "mst" for row in active_rows):
        raise ValueError(
            "MST push requires an explicit instance-to-VLAN mapping and is not supported"
        )
    if active_rows:
        commands.append(f"spanning-tree mode {active_rows[0]['stp_mode']}")
    for item in global_rows:
        vlan_id = item["vlan_id"]
        if item.get("action") == "remove":
            commands.append(f"no spanning-tree vlan {vlan_id} priority")
            continue
        if item["root_role"] in {"primary", "secondary"}:
            commands.append(f"spanning-tree vlan {vlan_id} root {item['root_role']}")
        else:
            commands.append(f"spanning-tree vlan {vlan_id} priority {item['priority']}")
    mapping = (
        ("portfast", "spanning-tree portfast"),
        ("bpduguard", "spanning-tree bpduguard enable"),
        ("bpdufilter", "spanning-tree bpdufilter enable"),
        ("root_guard", "spanning-tree guard root"),
        ("loop_guard", "spanning-tree guard loop"),
    )
    for item in payload["interfaces"]:
        commands.extend(_interface_header(item["if_name"]))
        for field, command in mapping:
            enabled_command = command
            if field == "portfast" and item.get("mode") == "trunk":
                enabled_command = "spanning-tree portfast trunk"
            commands.append(
                f" {enabled_command}"
                if item[field] == "enabled"
                else f" no {command}"
            )
        commands.append(" exit")
    return commands


def render_vtp(payload: dict[str, Any]) -> list[str]:
    rows = payload["vtp"]
    if not rows:
        return []
    first = rows[0]
    if first.get("success") == "pending_delete":
        return ["vtp mode transparent"]
    commands = [f"vtp domain {first['domain_name']}", f"vtp version {first['version']}"]
    vlan_mode = next((row["mode"] for row in rows if row["database_type"] == "vlan"), None)
    if vlan_mode:
        commands.append(f"vtp mode {vlan_mode}")
    if vlan_mode == "server":
        commands.append("vtp pruning" if first["pruning"] else "no vtp pruning")
    return commands


def render_security(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    # Only a global-settings task may change Option 82. Other policy tasks
    # must not re-enable insertion using an implicit default.
    if "global_config" in payload:
        option_82 = payload["global_config"]["dhcp_option_82"]
        if option_82 not in {"insert", "allow-untrusted", "disable"}:
            raise ValueError("Unsupported DHCP Option 82 mode")
        commands.append(
            "ip dhcp snooping information option allow-untrusted"
            if option_82 == "allow-untrusted"
            else "no ip dhcp snooping information option allow-untrusted"
        )
        commands.append(
            "no ip dhcp snooping information option"
            if option_82 == "disable"
            else "ip dhcp snooping information option"
        )
    snooping_vlans = [str(row["vlan_id"]) for row in payload["vlans"] if row["dhcp_snooping"]]
    if snooping_vlans:
        commands.extend(["ip dhcp snooping", f"ip dhcp snooping vlan {','.join(snooping_vlans)}"])
    for item in payload["vlans"]:
        if not item["dhcp_snooping"]:
            commands.append(f"no ip dhcp snooping vlan {item['vlan_id']}")
    dai_vlans = [str(row["vlan_id"]) for row in payload["vlans"] if row["dai_enabled"]]
    if dai_vlans:
        commands.append(f"ip arp inspection vlan {','.join(dai_vlans)}")
        # ARP ACLs are not managed here; keep their documented deny default.
        commands.append(f"no ip arp inspection vlan {','.join(dai_vlans)} logging acl-match")
        for item in payload["vlans"]:
            if not item["dai_enabled"]:
                continue
            mode = dai_log_mode(item.get("dai_log_mode"))
            prefix = f"ip arp inspection vlan {item['vlan_id']} logging dhcp-bindings"
            commands.append(f"no {prefix}" if mode == "deny" else f"{prefix} {mode}")
        # Bounded output with enough room for a small report/lab demonstration.
        commands.append("ip arp inspection log-buffer entries 128")
        commands.append("ip arp inspection log-buffer logs 10 interval 1")
    for item in payload["vlans"]:
        if not item["dai_enabled"]:
            commands.append(f"no ip arp inspection vlan {item['vlan_id']}")
    for entry in payload["trust_ports"]:
        name = entry.get("if_name") if isinstance(entry, dict) else entry
        if isinstance(entry, dict):
            action = entry.get("action")
            trust_dhcp = bool(entry.get("trust_dhcp", True))
            trust_arp = bool(entry.get("trust_arp", True))
        else:
            action = None
            trust_dhcp = True
            trust_arp = True
        
        commands.append(f"interface {name}")
        
        if action == "remove":
            if trust_dhcp:
                commands.append(" no ip dhcp snooping trust")
            if trust_arp:
                commands.append(" no ip arp inspection trust")
        else:
            commands.append(" ip dhcp snooping trust" if trust_dhcp else " no ip dhcp snooping trust")
            commands.append(" ip arp inspection trust" if trust_arp else " no ip arp inspection trust")
            
        commands.append(" exit")
    for item in payload["ports"]:
        if item["enabled"] and item["violation"] == "protect":
            raise ValueError(
                "Port Security protect drops packets without Syslog. "
                "Choose restrict or shutdown to monitor security violations."
            )
        commands.extend(_interface_header(item["if_name"]))
        if not item["enabled"]:
            commands.append(" no switchport port-security")
            commands.append(" exit")
            continue
        commands.extend(
            [
                " switchport mode access",
                " switchport port-security",
                f" switchport port-security maximum {item['max_mac']}",
                f" switchport port-security violation {item['violation']}",
            ]
        )
        if item["sticky"]:
            commands.append(" switchport port-security mac-address sticky")
        if item["aging_time"]:
            commands.extend(
                [
                    f" switchport port-security aging time {item['aging_time']}",
                    f" switchport port-security aging type {item['aging_type']}",
                ]
            )
        commands.append(" exit")
    for item in payload["static_macs"]:
        prefix = "no " if item.get("action") == "remove" else ""
        commands.append(
            f"{prefix}mac address-table static {item['mac_addr']} vlan {item['vlan_id']} interface {item['if_name']}"
        )
    return commands


RENDERERS = {
    "vlan": render_vlan,
    "svi": render_svi,
    "interfaces": render_interfaces,
    "stp": render_stp,
    "vtp": render_vtp,
    "security": render_security,
}


def render_commands(module_name: str, payload: dict[str, Any]) -> list[str]:
    try:
        return RENDERERS[module_name](payload)
    except KeyError as exc:
        raise ValueError(f"Unsupported Layer 2 module: {module_name}") from exc
