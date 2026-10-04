from features.interfaces.validation import validate_payload, InterfaceValidationError

payload = {
    "interface_name": "GigabitEthernet0/2",
    "ip_address": "dhcp",
    "subnet_mask": "",
    "secondary_ip": "",
    "secondary_mask": "",
    "interface_kind": "L3",
    "parent_interface": "",
    "vlan_id": "",
    "tunnel_src": "",
    "tunnel_dst": ""
}

print("Testing with payload:", payload)
try:
    print(validate_payload(payload, existing=True))
except Exception as e:
    print("Caught:", type(e), e)

payload["subnet_mask"] = "255.255.255.0"
print("\nTesting with payload:", payload)
try:
    print(validate_payload(payload, existing=True))
except Exception as e:
    print("Caught:", type(e), e)
