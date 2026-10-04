sed -i 's/    @pyqtSlot(str, result="QVariant")/    @pyqtSlot(str, result="QVariant")\n    def getSwitchL2Security(self, host: str) -> dict[str, Any]:\n        return get_l2_security(self, host)/' /data/Projects/CAMS_2/core/switch_slots.py
sed -i '/def getSwitchL2Security/,+2d' /data/Projects/CAMS_2/core/switch_slots.py
