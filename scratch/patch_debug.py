import re

with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "r") as f:
    text = f.read()

debug_code = """
    ip_text = str(address or "").strip()
    mask_text = str(mask or "").strip()
    print(f"DEBUG: normalize_ipv4 called with address='{address}', mask='{mask}', ip_text='{ip_text}', mask_text='{mask_text}'")
    if ip_text.lower() == "dhcp":
        return "dhcp", None
"""
text = text.replace("""    ip_text = str(address or "").strip()
    if ip_text.lower() == "dhcp":
        return "dhcp", None
    ip_text = str(address or "").strip()""", debug_code)

with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "w") as f:
    f.write(text)
