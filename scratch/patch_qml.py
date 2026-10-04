import re

with open("/data/Projects/CAMS_2/UI/qml/features/switching/security/L2SecurityPage.qml", "r") as f:
    text = f.read()

# Add checkboxes
old_combo = """                    StandardComboBox {
                        id: trustInterfaceCombo
                        objectName: "trustInterfaceCombo"
                        Layout.fillWidth: true
                        labelText: "Layer 2 interface"
                        model: root.availableTrustInterfaceLabels()
                        valueModel: root.availableTrustInterfaces()
                        emptyText: root.refreshingReferences
                                   ? "Refreshing interfaces..."
                                   : "No Layer 2 interfaces available"
                        emptyWarningText: "No usable Layer 2 interface is available. Complete or synchronize the Interfaces tab, then return here or select Reload UI."
                    }"""

new_combo = old_combo + """
                    StandardCheckBox {
                        id: trustDhcpCheck
                        Layout.fillWidth: true
                        text: "Trust DHCP Snooping"
                        checked: true
                    }
                    StandardCheckBox {
                        id: trustArpCheck
                        Layout.fillWidth: true
                        text: "Trust ARP Inspection"
                        checked: true
                    }"""

text = text.replace(old_combo, new_combo)

# Update addTrustPort call
old_add = "onClicked: root.addTrustPort(trustInterfaceCombo.currentValue)"
new_add = "onClicked: root.addTrustPort(trustInterfaceCombo.currentValue, trustDhcpCheck.checked, trustArpCheck.checked)"
text = text.replace(old_add, new_add)

# Update addTrustPort function definition
old_def = """    function addTrustPort(ifName) {
        const result = dbManager.addSwitchL2TrustPort(host, ifName)"""
new_def = """    function addTrustPort(ifName, trustDhcp, trustArp) {
        const result = dbManager.addSwitchL2TrustPort(host, ifName, trustDhcp, trustArp)"""
text = text.replace(old_def, new_def)

# Update DataTable display text
old_display = """DataTableCell { Layout.preferredWidth: 180; text: "DHCP + ARP trust"; color: Theme.alertSuccess }"""
new_display = """DataTableCell {
                                    Layout.preferredWidth: 180
                                    text: {
                                        if (model.trust_dhcp && model.trust_arp) return "DHCP + ARP trust"
                                        if (model.trust_dhcp) return "DHCP trust"
                                        if (model.trust_arp) return "ARP trust"
                                        return "No trust"
                                    }
                                    color: (model.trust_dhcp || model.trust_arp) ? Theme.alertSuccess : Theme.textSecondary
                                }"""
text = text.replace(old_display, new_display)

with open("/data/Projects/CAMS_2/UI/qml/features/switching/security/L2SecurityPage.qml", "w") as f:
    f.write(text)
print("QML Patched")
