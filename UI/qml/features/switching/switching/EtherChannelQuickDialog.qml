pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: dialog

    property string sourceHost: ""
    property var ownerForm: null
    property var sourceData: ({})
    property var targetRows: []
    property var sourcePortLabels: []
    property var sourcePortValues: []
    property var targetLabels: []
    property var targetValues: []
    property var targetPortLabels: []
    property var targetPortValues: []
    property var commonVlanLabels: []
    property var commonVlanValues: []
    property int stepIndex: 0
    property string poNumber: "1"
    property string protocol: "lacp"
    property string switchportMode: "trunk"
    property string allowedVlans: "all"
    property string errorText: ""

    signal saved(var hosts)

    preferredWidth: 760
    height: Math.min(parent ? parent.height - 48 : 610, 650)
    title: "Quick EtherChannel"
    subtitle: "Build one matching link between two switches"

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
    }

    function listCount(value) {
        if (!value) return 0
        if (typeof value.count === "number") return value.count
        return value.length || 0
    }

    function listItem(value, index) {
        return value && typeof value.get === "function" ? value.get(index) : value[index]
    }

    function labelsAndValues(rows, labelBuilder, valueKey) {
        const labels = []
        const values = []
        for (let index = 0; index < listCount(rows); index++) {
            const row = listItem(rows, index)
            labels.push(labelBuilder(row))
            values.push(String(row[valueKey] || ""))
        }
        return { labels: labels, values: values }
    }

    function selectedTarget() {
        const index = targetHostCombo.currentIndex
        return index >= 0 && index < listCount(targetRows)
             ? listItem(targetRows, index) : null
    }

    function rebuildTargetDetails() {
        const target = selectedTarget()
        const ports = target ? target.ports || [] : []
        const portOptions = labelsAndValues(
            ports,
            function(row) {
                return String(row.if_name || "") + " · "
                     + String(row.mode || "access") + " · "
                     + String(row.speed || "auto") + "/"
                     + String(row.duplex || "auto")
            },
            "if_name"
        )
        targetPortLabels = portOptions.labels
        targetPortValues = portOptions.values
        targetPortCombo.currentIndex = targetPortValues.length > 0 ? 0 : -1

        const sourceVlans = sourceData.vlans || []
        const targetVlans = target ? target.vlans || [] : []
        const targetSet = ({})
        for (let index = 0; index < listCount(targetVlans); index++)
            targetSet[String(listItem(targetVlans, index))] = true
        const labels = []
        const values = []
        for (let sourceIndex = 0; sourceIndex < listCount(sourceVlans); sourceIndex++) {
            const vlan = String(listItem(sourceVlans, sourceIndex))
            if (targetSet[vlan]) {
                labels.push("VLAN " + vlan)
                values.push(vlan)
            }
        }
        commonVlanLabels = labels
        commonVlanValues = values
        vlanCombo.currentIndex = values.length > 0 ? 0 : -1
    }

    function openFor(host, form) {
        sourceHost = String(host || "").trim()
        ownerForm = form || null
        stepIndex = 0
        switchportMode = "trunk"
        protocol = "lacp"
        protocolCombo.currentIndex = 0
        allowedVlans = "all"
        errorText = ""
        const result = dbManager.getEtherChannelQuickOptions(sourceHost)
        if (!result || result.ok !== true) {
            notify(String(result && result.message
                          ? result.message : "Quick EtherChannel is unavailable."), "error")
            return false
        }
        sourceData = result.source || ({})
        targetRows = result.targets || []
        poNumber = String(result.suggestedPoNumber || 1)

        const sourceOptions = labelsAndValues(
            sourceData.ports || [],
            function(row) {
                return String(row.if_name || "") + " · "
                     + String(row.mode || "access") + " · "
                     + String(row.speed || "auto") + "/"
                     + String(row.duplex || "auto")
            },
            "if_name"
        )
        sourcePortLabels = sourceOptions.labels
        sourcePortValues = sourceOptions.values
        const hostOptions = labelsAndValues(
            targetRows,
            function(row) {
                const name = String(row.device_name || "").trim()
                return name === "" ? String(row.host || "")
                                   : name + " · " + String(row.host || "")
            },
            "host"
        )
        targetLabels = hostOptions.labels
        targetValues = hostOptions.values
        sourcePortCombo.currentIndex = sourcePortValues.length > 0 ? 0 : -1
        targetHostCombo.currentIndex = targetValues.length > 0 ? 0 : -1
        rebuildTargetDetails()
        open()
        return true
    }

    function stepValid() {
        errorText = ""
        if (stepIndex === 0) {
            if (sourcePortCombo.currentIndex < 0) {
                errorText = "The current switch has no available physical port."
                return false
            }
            const number = Number(poNumber)
            if (poNumber.trim() === "" || !Number.isInteger(number)
                    || number < 1 || number > 4096) {
                errorText = "Port-channel number must be between 1 and 4096."
                return false
            }
        } else if (stepIndex === 1) {
            if (targetHostCombo.currentIndex < 0) {
                errorText = "Choose a connected peer switch."
                return false
            }
            if (targetPortCombo.currentIndex < 0) {
                errorText = "The selected peer has no available physical port."
                return false
            }
        } else if (stepIndex === 2) {
            if (vlanCombo.currentIndex < 0) {
                errorText = "The two switches do not have a common active VLAN."
                return false
            }
            if (switchportMode === "trunk" && allowedVlans.trim() === "") {
                errorText = "Enter allowed VLANs or use all."
                return false
            }
        }
        return true
    }

    function saveAndPush() {
        if (!stepValid()) return
        const result = dbManager.saveEtherChannelQuick({
            source_host: sourceHost,
            source_port: sourcePortCombo.currentValue,
            target_host: targetHostCombo.currentValue,
            target_port: targetPortCombo.currentValue,
            po_number: Number(poNumber),
            protocol: protocol,
            switchport_mode: switchportMode,
            access_vlan: Number(vlanCombo.currentValue),
            native_vlan: Number(vlanCombo.currentValue),
            allowed_vlans: allowedVlans.trim()
        })
        notify(String(result.message || ""), result.ok ? "success" : "error")
        if (!result.ok) {
            errorText = String(result.message || "Quick EtherChannel could not be saved.")
            return
        }
        close()
        saved(result.successful || [])
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["1. Local port", "2. Peer port", "3. Link mode"]
                delegate: Rectangle {
                    id: stepChip
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.radiusSmall
                    color: index === dialog.stepIndex
                           ? Theme.accentColor : Theme.contentPanelSurface
                    border.color: index <= dialog.stepIndex
                                  ? Theme.accentColor : Theme.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: stepChip.index === dialog.stepIndex
                               ? Theme.buttonTextSolid : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }
                }
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            visible: dialog.errorText !== ""
            severity: "warning"
            message: dialog.errorText
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacing12

                FormSection {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 0
                    title: "Current switch · " + dialog.sourceHost
                    helpText: "Choose one free physical port. Quick Setup uses the same Port-channel number and negotiation protocol at both ends."

                    StandardComboBox {
                        id: sourcePortCombo
                        objectName: "quickEtherChannelSourcePortCombo"
                        Layout.fillWidth: true
                        labelText: "Local member port"
                        model: dialog.sourcePortLabels
                        valueModel: dialog.sourcePortValues
                        emptyText: "No free physical ports"
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: dialog.width < 620 ? 1 : 2
                        columnSpacing: Theme.spacing12
                        rowSpacing: Theme.spacing8
                        StandardTextField {
                            Layout.fillWidth: true
                            labelText: "Port-channel number"
                            text: dialog.poNumber
                            placeholderText: "1–4096"
                            onTextEdited: value => dialog.poNumber = value
                        }
                        StandardComboBox {
                            id: protocolCombo
                            Layout.fillWidth: true
                            labelText: "Protocol"
                            model: ["LACP (recommended)", "PAgP", "Static"]
                            valueModel: ["lacp", "pagp", "static"]
                            onActivated: dialog.protocol = currentValue
                        }
                    }
                }

                FormSection {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 1
                    title: "Peer switch"
                    helpText: "Choose the switch at the other end of this physical link, then choose its matching port."

                    StandardComboBox {
                        id: targetHostCombo
                        objectName: "quickEtherChannelTargetHostCombo"
                        Layout.fillWidth: true
                        labelText: "Connect to"
                        model: dialog.targetLabels
                        valueModel: dialog.targetValues
                        emptyText: "No other connected switch"
                        onActivated: dialog.rebuildTargetDetails()
                    }
                    StandardComboBox {
                        id: targetPortCombo
                        objectName: "quickEtherChannelTargetPortCombo"
                        Layout.fillWidth: true
                        labelText: "Peer member port"
                        model: dialog.targetPortLabels
                        valueModel: dialog.targetPortValues
                        emptyText: "No free physical ports"
                    }
                }

                FormSection {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 2
                    title: "Switchport mode"
                    helpText: "Both member ports and both Port-channel interfaces receive the same Layer 2 mode. Only the fields required by that mode are shown."

                    RowLayout {
                        Layout.fillWidth: true
                        StandardButton {
                            Layout.fillWidth: true
                            text: "Trunk"
                            type: dialog.switchportMode === "trunk" ? "Primary" : "Secondary"
                            onClicked: dialog.switchportMode = "trunk"
                        }
                        StandardButton {
                            Layout.fillWidth: true
                            text: "Access"
                            type: dialog.switchportMode === "access" ? "Primary" : "Secondary"
                            onClicked: dialog.switchportMode = "access"
                        }
                    }
                    StandardComboBox {
                        id: vlanCombo
                        objectName: "quickEtherChannelVlanCombo"
                        Layout.fillWidth: true
                        labelText: dialog.switchportMode === "trunk"
                                   ? "Native VLAN" : "Access VLAN"
                        model: dialog.commonVlanLabels
                        valueModel: dialog.commonVlanValues
                        emptyText: "No common VLAN"
                    }
                    StandardTextField {
                        Layout.fillWidth: true
                        visible: dialog.switchportMode === "trunk"
                        labelText: "Allowed VLANs"
                        text: dialog.allowedVlans
                        placeholderText: "all or 10,20,30-40"
                        onTextEdited: value => dialog.allowedVlans = value
                    }

                    InlineMessage {
                        Layout.fillWidth: true
                        severity: "info"
                        message: "Ready: " + dialog.sourceHost + " / "
                                 + sourcePortCombo.currentValue + "  ↔  "
                                 + targetHostCombo.currentValue + " / "
                                 + targetPortCombo.currentValue
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: "Back"
                type: "Text"
                enabled: dialog.stepIndex > 0
                onClicked: dialog.stepIndex--
            }
            Item { Layout.fillWidth: true }
            StandardButton {
                text: "Cancel"
                type: "Text"
                onClicked: dialog.close()
            }
            StandardButton {
                visible: dialog.stepIndex < 2
                text: "Next"
                type: "Primary"
                onClicked: if (dialog.stepValid()) dialog.stepIndex++
            }
            StandardButton {
                objectName: "quickEtherChannelSavePushButton"
                visible: dialog.stepIndex === 2
                text: "Save & Push Both"
                icon.source: AppAssets.actionPush
                type: "Primary"
                onClicked: dialog.saveAndPush()
            }
        }
    }
}
