pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground

    readonly property var backend:
        typeof automationManager !== "undefined" ? automationManager : null
    property string selectedRuleId: ""
    property string selectedRuleFile: ""
    property string resultMessage: ""
    property bool resultOk: true
    property bool visualMode: true

    function showResult(result, fallback) {
        resultOk = result && result.ok === true
        resultMessage = result && result.message
            ? String(result.message) : fallback
    }

    function resetBuilder() {
        builderRuleId.text = "shutdown-interface-on-event"
        builderName.text = "Shutdown interface on security event"
        builderDescription.text = "Close a fixed interface through the active CAMS SSH session when the event matches."
        builderEventType.text = "ICMP_FLOOD"
        builderNetwork.text = ""
        builderSubnetMask.text = ""
        builderInterface.text = "GigabitEthernet0/3"
        builderProtocol.currentIndex = 0
        builderAction.currentIndex = 0
        builderInterval.value = 1
        builderCooldown.value = 300
        builderHourly.value = 2
        builderEnabled.checked = true
    }

    function builderPayload() {
        const matchValue = {
            "event_type": builderEventType.text.trim(),
            "require_attributes": [],
            "attributes": { "protocol": builderProtocol.currentValue }
        }
        if (builderNetwork.text.trim() !== ""
                && builderSubnetMask.text.trim() !== "") {
            matchValue.network = builderNetwork.text.trim()
            matchValue.subnet_mask = builderSubnetMask.text.trim()
        }
        return {
            "version": 1,
            "metadata": {
                "id": builderRuleId.text.trim(),
                "name": builderName.text.trim(),
                "description": builderDescription.text.trim(),
                "enabled": builderEnabled.checked
            },
            "schedule": { "interval_seconds": builderInterval.value },
            "match": matchValue,
            "policy": {
                "mode": "auto",
                "cooldown_seconds": builderCooldown.value,
                "max_actions_per_hour": builderHourly.value
            },
            "action": {
                "type": "interface.admin-state",
                "transport": "ssh",
                "interface": builderInterface.text.trim(),
                "enabled": builderAction.currentIndex === 1,
                "ttl_seconds": 0
            }
        }
    }

    function generateFromBuilder(showMessage) {
        if (builderRuleId.text.trim() === ""
                || builderName.text.trim() === ""
                || builderEventType.text.trim() === ""
                || builderInterface.text.trim() === "") {
            resultOk = false
            resultMessage = "Rule ID, name, event type and interface are required."
            return false
        }
        if ((builderNetwork.text.trim() === "")
                !== (builderSubnetMask.text.trim() === "")) {
            resultOk = false
            resultMessage = "Network and subnet mask must be filled together."
            return false
        }
        ruleEditor.text = JSON.stringify(builderPayload(), null, 2) + "\n"
        if (showMessage) {
            resultOk = true
            resultMessage = "Generated a typed SSH rule. Open JSON mode to review the exact .rule.cams payload."
        }
        return true
    }

    function syncBuilderFromText() {
        if (ruleEditor.text.trim() === "") {
            resetBuilder()
            return true
        }
        try {
            const value = JSON.parse(ruleEditor.text)
            const matchValue = value.match || {}
            const required = Array.isArray(matchValue.require_attributes)
                             ? matchValue.require_attributes : []
            const attributes = matchValue.attributes || {}
            const attributeKeys = Object.keys(attributes)
            const quickBuilderSafe = Number(value.version) === 1
                    && value.action
                    && value.action.type === "interface.admin-state"
                    && Boolean(value.action.interface)
                    && value.action.transport === "ssh"
                    && Number(value.action.ttl_seconds || 0) === 0
                    && value.policy && value.policy.mode === "auto"
                    && required.length === 0
                    && attributeKeys.every(function(key) { return key === "protocol" })
            if (!quickBuilderSafe) {
                resultOk = true
                resultMessage = "This rule contains advanced fields that Quick Builder cannot safely preserve. Continue in Advanced JSON mode."
                return false
            }
            builderRuleId.text = String(value.metadata.id || "")
            builderName.text = String(value.metadata.name || "")
            builderDescription.text = String(value.metadata.description || "")
            builderEnabled.checked = Boolean(value.metadata.enabled)
            builderEventType.text = String(value.match.event_type || "")
            builderNetwork.text = String(value.match.network || "")
            builderSubnetMask.text = String(value.match.subnet_mask || "")
            const protocol = String((value.match.attributes || {}).protocol || "icmp")
            builderProtocol.currentIndex = Math.max(0, builderProtocol.valueModel.indexOf(protocol))
            builderAction.currentIndex = value.action.enabled === true ? 1 : 0
            builderInterface.text = String(value.action.interface || "")
            builderInterval.value = Number(value.schedule.interval_seconds || 1)
            builderCooldown.value = Number(value.policy.cooldown_seconds || 0)
            builderHourly.value = Number(value.policy.max_actions_per_hour || 1)
            return true
        } catch (error) {
            resultOk = false
            resultMessage = "Cannot open Quick Builder: " + String(error)
            return false
        }
    }

    function showVisualBuilder() {
        if (syncBuilderFromText())
            visualMode = true
    }

    function showJsonEditor() {
        if (visualMode && !generateFromBuilder(false))
            return
        visualMode = false
        ruleEditor.forceActiveFocus()
    }

    function newRule() {
        selectedRuleId = ""
        selectedRuleFile = ""
        ruleEditor.text = ""
        resultMessage = ""
        resetBuilder()
        visualMode = true
        builderRuleId.forceActiveFocus()
    }

    function loadIcmpExample() {
        selectedRuleId = ""
        selectedRuleFile = ""
        ruleEditor.text = backend !== null ? backend.sampleIcmpRule() : ""
        resultMessage = "Dry-run ACL example loaded in Advanced JSON mode. Review it, then save and enable it explicitly."
        resultOk = true
        visualMode = false
        ruleEditor.forceActiveFocus()
    }

    function loadCliExample() {
        selectedRuleId = ""
        selectedRuleFile = ""
        ruleEditor.text = backend !== null ? backend.sampleCliRule() : ""
        resultMessage = "Version 2 SSH CLI example loaded disabled. Review every command before saving and enabling it."
        resultOk = true
        visualMode = false
        ruleEditor.forceActiveFocus()
    }

    function openRule(ruleId, fileName) {
        if (backend === null)
            return
        const result = backend.getRule(String(fileName || ""))
        showResult(result, "Unable to load the selected rule.")
        if (result && result.ok) {
            selectedRuleId = String(ruleId || "")
            selectedRuleFile = String(fileName || "")
            ruleEditor.text = String(result.text || "")
            visualMode = syncBuilderFromText()
        }
    }

    function saveCurrentRule() {
        if (visualMode && !generateFromBuilder(false))
            return
        const result = backend.saveRule(ruleEditor.text, selectedRuleFile)
        showResult(result, "Unable to save the rule.")
        if (result && result.ok) {
            selectedRuleId = String(result.id)
            selectedRuleFile = String(result.file_name || "")
        }
    }

    Component.onCompleted: {
        if (ruleEditor.text.trim() === "")
            resetBuilder()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing4
                Text {
                    text: root.selectedRuleId === ""
                          ? "Automation Rule Editor" : "Edit " + root.selectedRuleId
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.selectedRuleFile === ""
                          ? "Build a version 1 interface action visually, or edit strict version 1/2 JSON."
                          : "File: " + root.selectedRuleFile
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: root.selectedRuleFile === ""
                                 ? Theme.fontFamily : Theme.monoFontFamily
                    elide: Text.ElideMiddle
                }
            }

            StandardButton {
                text: "New"
                type: "Text"
                icon.source: AppAssets.actionClear
                onClicked: root.newRule()
            }
            StandardButton {
                objectName: "automationIcmpSampleButton"
                text: "Dry-run ACL Example"
                icon.source: AppAssets.actionCopy
                enabled: root.backend !== null
                onClicked: root.loadIcmpExample()
            }
            StandardButton {
                objectName: "automationCliSampleButton"
                text: "CLI v2 Example"
                icon.source: AppAssets.actionCopy
                enabled: root.backend !== null
                onClicked: root.loadCliExample()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8
            Text {
                text: "Editor:"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
            StandardButton {
                objectName: "automationVisualBuilderButton"
                text: "Quick Builder"
                type: root.visualMode ? "Primary" : "Text"
                onClicked: root.showVisualBuilder()
            }
            StandardButton {
                objectName: "automationJsonEditorButton"
                text: "Advanced JSON"
                type: root.visualMode ? "Text" : "Primary"
                onClicked: root.showJsonEditor()
            }
            Item { Layout.fillWidth: true }
            StandardBadge {
                text: root.visualMode ? "AUTO · SSH · TYPED" : "STRICT JSON V1/V2"
                badgeColor: root.visualMode ? Theme.alertSuccess : Theme.accentEmphasis
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            message: root.visualMode
                     ? "Quick Builder creates shutdown/no-shutdown rules for one fixed interface. CAMS generates and verifies the SSH commands."
                     : "Version 1 keeps typed actions. Version 2 accepts bounded SSH CLI commands with action.mode config or exec."
            severity: "info"
        }

        Rectangle {
            objectName: "automationQuickBuilder"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.visualMode
            color: Theme.searchBackground2
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.spacing12

                    Text {
                        Layout.fillWidth: true
                        text: "Trigger and identity"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    GridLayout {
                        id: builderIdentityGrid
                        Layout.fillWidth: true
                        columns: width >= 900 ? 3 : (width >= 600 ? 2 : 1)
                        columnSpacing: Theme.spacing12
                        rowSpacing: Theme.spacing8

                        StandardTextField {
                            id: builderRuleId
                            objectName: "automationBuilderRuleId"
                            Layout.fillWidth: true
                            labelText: "Rule ID"
                            placeholderText: "shutdown-gi0-3-on-icmp-flood"
                        }
                        StandardTextField {
                            id: builderName
                            Layout.fillWidth: true
                            labelText: "Display name"
                            placeholderText: "Shutdown Gi0/3 on ICMP flood"
                        }
                        StandardTextField {
                            id: builderEventType
                            Layout.fillWidth: true
                            labelText: "Event type"
                            placeholderText: "ICMP_FLOOD"
                        }
                        StandardTextField {
                            id: builderNetwork
                            objectName: "automationBuilderNetwork"
                            Layout.fillWidth: true
                            labelText: "Device network (optional)"
                            placeholderText: "192.168.122.0"
                        }
                        StandardTextField {
                            id: builderSubnetMask
                            objectName: "automationBuilderSubnetMask"
                            Layout.fillWidth: true
                            labelText: "Subnet mask (optional)"
                            placeholderText: "255.255.255.0"
                        }
                        StandardTextField {
                            id: builderDescription
                            Layout.fillWidth: true
                            Layout.columnSpan: builderIdentityGrid.columns
                            labelText: "Description"
                            placeholderText: "What this rule does"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "SSH action"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    GridLayout {
                        id: builderActionGrid
                        Layout.fillWidth: true
                        columns: width >= 900 ? 3 : (width >= 600 ? 2 : 1)
                        columnSpacing: Theme.spacing12
                        rowSpacing: Theme.spacing8

                        StandardComboBox {
                            id: builderAction
                            objectName: "automationBuilderAction"
                            Layout.fillWidth: true
                            labelText: "Interface action"
                            model: ["Shutdown (admin down)", "No shutdown (admin up)"]
                            valueModel: ["shutdown", "no-shutdown"]
                        }
                        StandardTextField {
                            id: builderInterface
                            objectName: "automationBuilderInterface"
                            Layout.fillWidth: true
                            labelText: "Fixed interface"
                            placeholderText: "GigabitEthernet0/3"
                        }
                        StandardComboBox {
                            id: builderProtocol
                            Layout.fillWidth: true
                            labelText: "Match protocol"
                            model: ["ICMP", "TCP", "UDP", "IP"]
                            valueModel: ["icmp", "tcp", "udp", "ip"]
                        }
                        StandardSpinBox {
                            id: builderInterval
                            Layout.fillWidth: true
                            labelText: "Scan interval (seconds)"
                            from: 1
                            to: 3600
                            value: 1
                        }
                        StandardSpinBox {
                            id: builderCooldown
                            Layout.fillWidth: true
                            labelText: "Cooldown (seconds)"
                            from: 0
                            to: 86400
                            value: 300
                        }
                        StandardSpinBox {
                            id: builderHourly
                            Layout.fillWidth: true
                            labelText: "Maximum actions/hour"
                            from: 1
                            to: 1000
                            value: 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing12
                        StandardCheckBox {
                            id: builderEnabled
                            text: "Enable this rule after saving"
                            checked: true
                        }
                        Item { Layout.fillWidth: true }
                        StandardButton {
                            objectName: "automationGenerateJsonButton"
                            text: "Generate JSON Preview"
                            icon.source: AppAssets.actionCopy
                            onClicked: {
                                if (root.generateFromBuilder(true))
                                    root.visualMode = false
                            }
                        }
                    }

                    InlineMessage {
                        Layout.fillWidth: true
                        message: "Generated device sequence: configure terminal → interface "
                                 + builderInterface.text + " → "
                                 + (builderAction.currentIndex === 1 ? "no shutdown" : "shutdown")
                                 + " → end → verify state."
                        severity: "warning"
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.visualMode
            color: Theme.searchBackground2
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                clip: true
                TextArea {
                    id: ruleEditor
                    objectName: "automationRuleEditor"
                    width: Math.max(parent.availableWidth, contentWidth)
                    height: Math.max(parent.availableHeight, contentHeight)
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    color: Theme.textPrimary
                    selectedTextColor: Theme.selectionForeground
                    selectionColor: Theme.selectionBackground
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    background: Rectangle { color: "transparent" }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.resultMessage !== ""
            text: root.resultMessage
            color: root.resultOk ? Theme.alertSuccess : Theme.alertError
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StandardButton {
                objectName: "automationSaveRuleButton"
                text: root.visualMode ? "Build & Save Rule" : "Validate & Save JSON"
                type: "Primary"
                icon.source: AppAssets.actionSave
                enabled: root.backend !== null
                         && (root.visualMode || ruleEditor.text.trim() !== "")
                onClicked: root.saveCurrentRule()
            }
        }
    }
}
