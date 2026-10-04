import sys
import os
sys.path.append(os.path.abspath("/data/Projects/CAMS_2"))
from features.syslog.application.security_events import _classify_dhcp_snooping

row = {
    "cisco_facility": "SYS",
    "message": "DHCP_SNOOPING: drop message on untrusted port, message type: DHCPOFFER, MAC sa: 0050.56b3.8d6e",
    "device_host": "192.168.122.101"
}

event = _classify_dhcp_snooping(row)
print(f"Event: {event}")
