with open("/data/Projects/CAMS_2/UI/qml/features/switching/security/L2SecurityPage.qml", "r") as f:
    text = f.read()

# Fix 1: replaceTrustPorts
old_replace = """    function replaceTrustPorts(rows) {
        trustPortModel.clear()
        for (let i = 0; i < rows.length; i++) {
            trustPortModel.append({
                id: Number(rows[i].id || 0),
                if_name: String(rows[i].if_name || ""),
                success: String(rows[i].success || "pending_apply")
            })
        }
    }"""
new_replace = """    function replaceTrustPorts(rows) {
        trustPortModel.clear()
        for (let i = 0; i < rows.length; i++) {
            trustPortModel.append({
                id: Number(rows[i].id || 0),
                if_name: String(rows[i].if_name || ""),
                trust_dhcp: Boolean(rows[i].trust_dhcp),
                trust_arp: Boolean(rows[i].trust_arp),
                success: String(rows[i].success || "pending_apply")
            })
        }
    }"""
if old_replace in text:
    text = text.replace(old_replace, new_replace)
else:
    print("Failed to find replaceTrustPorts")

# Fix 2: availableTrustInterfaces
old_avail = """            for (let j = 0; j < trustPortModel.count; j++) {
                if (trustPortModel.get(j).if_name === candidate) {
                    alreadyTrusted = true
                    break
                }
            }"""
new_avail = """            for (let j = 0; j < trustPortModel.count; j++) {
                if (trustPortModel.get(j).if_name === candidate) {
                    const row = trustPortModel.get(j)
                    if (row.trust_dhcp && row.trust_arp) {
                        alreadyTrusted = true
                    }
                    break
                }
            }"""
if old_avail in text:
    text = text.replace(old_avail, new_avail)
else:
    print("Failed to find availableTrustInterfaces loop")

with open("/data/Projects/CAMS_2/UI/qml/features/switching/security/L2SecurityPage.qml", "w") as f:
    f.write(text)
print("Fixes applied.")
