sed -i 's/if _facility(row) != "DHCP_SNOOPING":/if _facility(row) != "DHCP_SNOOPING" and not "DHCP_SNOOPING" in _text(row):/' /data/Projects/CAMS_2/features/syslog/application/security_events.py
