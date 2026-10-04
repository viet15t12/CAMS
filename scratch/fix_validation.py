import sys
with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "r") as f:
    text = f.read()

# I will just write the original validation.py up to validate_payload
prefix = text.split("def validate_payload")[0]

rest = """def validate_payload(payload: dict[str, Any], *, existing: bool = False) -> dict[str, Any]:
    normalized = dict(payload)
    name = canonical_interface_name(normalized.get("interface_name"))
    if not name or not __import__('re').fullmatch(r"[A-Za-z][A-Za-z-]*\d[\d/]*(?:\.\d+)?", name):
        raise InterfaceValidationError("Interface name is invalid")
    normalized["interface_name"] = name
    address, mask = normalize_ipv4(
        normalized.get("ip_address"), normalized.get("subnet_mask")
    )
    normalized["ip_address"] = address
    normalized["subnet_mask"] = mask

    secondary_ip = normalized.get("secondary_ip")
    secondary_mask = normalized.get("secondary_mask")
    if secondary_ip or secondary_mask:
        secondary_ip, secondary_mask = normalize_ipv4(secondary_ip, secondary_mask)
    normalized["secondary_ip"] = secondary_ip
    normalized["secondary_mask"] = secondary_mask

    interface_type = infer_interface_type(name, normalized.get("interface_kind"))
    normalized["interface_type"] = interface_type.value
    requested_kind = str(normalized.get("interface_kind") or "L3").strip()
    allowed_kinds = {
        InterfaceType.PHYSICAL: {"L3", "WAN"},
        InterfaceType.LOOPBACK: {"L3"},
        InterfaceType.TUNNEL: {"Tunnel"},
        InterfaceType.SUBINTERFACE: {"Subinterface"},
    }
    if requested_kind not in allowed_kinds[interface_type]:
        raise InterfaceValidationError(
            f"{interface_type.value} interface does not support the {requested_kind} profile"
        )
    if interface_type is InterfaceType.TUNNEL:
        source = str(normalized.get("tunnel_src") or "").strip()
        destination = str(normalized.get("tunnel_dst") or "").strip()
        if not source or not destination:
            raise InterfaceValidationError("Tunnel source and destination are required")
        try:
            import ipaddress
            ipaddress.IPv4Address(destination)
        except ValueError as exc:
            raise InterfaceValidationError("Tunnel destination must be a valid IPv4 address") from exc
        normalized_source = canonical_interface_name(source)
        try:
            import ipaddress
            ipaddress.IPv4Address(normalized_source)
        except ValueError:
            if not __import__('re').fullmatch(r"[A-Za-z][A-Za-z-]*\d[\d/]*(?:\.\d+)?", normalized_source):
                raise InterfaceValidationError(
                    "Tunnel source must be a valid IPv4 address or interface name"
                )
        normalized["tunnel_src"] = normalized_source
        normalized["tunnel_dst"] = destination
    if not existing and interface_type is InterfaceType.PHYSICAL:
        raise InterfaceValidationError("Physical interfaces must come from device discovery/profile")
    return normalized
"""
with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "w") as f:
    f.write(prefix + rest)
