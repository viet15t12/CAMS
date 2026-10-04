sed -i '/if interface.get("ip_address") and interface.get("subnet_mask"):/{
    i\        ip_text = str(interface.get("ip_address") or "").lower()
    i\        if ip_text == "dhcp":
    i\            commands.append("ip address dhcp")
    i\        elif interface.get("ip_address") and interface.get("subnet_mask"):
    d
}' /data/Projects/CAMS_2/features/interfaces/commands.py
