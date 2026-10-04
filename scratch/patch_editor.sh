sed -i 's/id: maskField;/id: maskField; visible: ipField.text.trim().toLowerCase() !== "dhcp";/' /data/Projects/CAMS_2/UI/qml/features/interfaces/InterfaceEditorPane.qml
