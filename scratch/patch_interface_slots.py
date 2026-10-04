with open("/data/Projects/CAMS_2/core/interface_slots.py", "r") as f:
    text = f.read()

new_slot = """    @pyqtSlot("QVariant", result="QVariant")
    def saveRouterInterfaceResult(self, payload: Any) -> dict[str, Any]:
        print("DEBUG PAYLOAD RECEIVED FROM QML:", payload)
        return InterfaceService(self).save(payload)"""

import re
text = re.sub(r'    @pyqtSlot\("QVariant", result="QVariant"\)\s+def saveRouterInterfaceResult.*?return InterfaceService\(self\)\.save\(payload\)', new_slot, text, flags=re.DOTALL)

with open("/data/Projects/CAMS_2/core/interface_slots.py", "w") as f:
    f.write(text)
