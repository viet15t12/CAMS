with open("/data/Projects/CAMS_2/UI/qml/features/interfaces/InterfaceEditorPane.qml", "r") as f:
    text = f.read()

old_ip = """StandardNetworkField { id: ipField; Layout.fillWidth: true; Layout.columnSpan: text.trim().toLowerCase() === "dhcp" ? 2 : 1; inputKind: "ipv4"; labelText: "IPv4 address"; placeholderText: "192.168.1.1" }"""
new_ip = """StandardNetworkField { id: ipField; Layout.fillWidth: true; Layout.columnSpan: (ipField.text || "").trim().toLowerCase() === "dhcp" ? 2 : 1; inputKind: "ipv4"; labelText: "IPv4 address"; placeholderText: "192.168.1.1" }"""

old_mask = """StandardNetworkField { id: maskField; visible: ipField.text.trim().toLowerCase() !== "dhcp"; Layout.fillWidth: true; inputKind: "subnet"; labelText: "Subnet mask"; placeholderText: "255.255.255.0 or /24" }"""
new_mask = """StandardNetworkField { id: maskField; visible: (ipField.text || "").trim().toLowerCase() !== "dhcp"; Layout.fillWidth: true; inputKind: "subnet"; labelText: "Subnet mask"; placeholderText: "255.255.255.0 or /24" }"""

if old_ip in text: text = text.replace(old_ip, new_ip)
if old_mask in text: text = text.replace(old_mask, new_mask)

with open("/data/Projects/CAMS_2/UI/qml/features/interfaces/InterfaceEditorPane.qml", "w") as f:
    f.write(text)
