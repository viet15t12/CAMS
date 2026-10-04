with open("/data/Projects/CAMS_2/features/switching/commands.py", "r") as f:
    text = f.read()

old_block = """    for entry in payload["trust_ports"]:
        name = entry.get("if_name") if isinstance(entry, dict) else entry
        commands.extend(
            [
                f"interface {name}",
                (
                    " no ip dhcp snooping trust"
                    if isinstance(entry, dict) and entry.get("action") == "remove"
                    else " ip dhcp snooping trust"
                ),
                (
                    " no ip arp inspection trust"
                    if isinstance(entry, dict) and entry.get("action") == "remove"
                    else " ip arp inspection trust"
                ),
                " exit",
            ]
        )"""

new_block = """    for entry in payload["trust_ports"]:
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
            
        commands.append(" exit")"""

if old_block in text:
    with open("/data/Projects/CAMS_2/features/switching/commands.py", "w") as f:
        f.write(text.replace(old_block, new_block))
    print("Patched successfully")
else:
    print("Old block not found!")
