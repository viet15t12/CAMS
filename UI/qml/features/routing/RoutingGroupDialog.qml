pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

// Four-step workflow for creating one OSPF/EIGRP configuration on many hosts.
StandardDialog {
    id: dialog

    property string protocol: "ospf"
    property int stepIndex: 0
    property var ownerForm: null
    property var hostRows: []
    property int selectedCount: 0
    property alias groupedNetworks: groupedNetworkModel
    readonly property int maxHosts: Math.max(2, targetModel.count)
    property string errorText: ""

    preferredWidth: 920
    height: Math.min(parent ? parent.height - 48 : 720, 760)
    title: "Routing Group · " + protocol.toUpperCase()
    subtitle: "Configure the same routing policy on multiple devices"

    ListModel { id: targetModel }
    ListModel { id: groupedNetworkModel }

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
    }

    function openFor(kind, form) {
        protocol = String(kind || "ospf").toLowerCase()
        ownerForm = form || null
        stepIndex = 0
        errorText = ""
        const result = dbManager.getRoutingGroupOptions()
        populateTargets(result && result.hosts ? result.hosts : [])
        open()
    }

    function populateTargets(rows) {
        hostRows = rows || []
        selectedCount = 0
        targetModel.clear()
        groupedNetworkModel.clear()
        for (let i = 0; i < hostRows.length; i++) {
            targetModel.append({
                host: String(hostRows[i].host),
                deviceName: String(hostRows[i].device_name || ""),
                role: String(hostRows[i].role || ""),
                selected: false,
                processId: "",
                routerId: "",
                networks: hostRows[i].networks || []
            })
        }
    }

    function collectionCount(collection) {
        if (!collection)
            return 0
        if (typeof collection.count === "number")
            return collection.count
        return collection.length || 0
    }

    function collectionItem(collection, index) {
        if (collection && typeof collection.get === "function")
            return collection.get(index)
        return collection[index]
    }

    function updateSelected(index, selected) {
        if (index < 0 || index >= targetModel.count)
            return
        const row = targetModel.get(index)
        if (Boolean(row.selected) === Boolean(selected))
            return
        if (selected && selectedCount >= maxHosts) {
            errorText = "A Routing Group supports at most " + maxHosts + " hosts."
            targetModel.setProperty(index, "selected", false)
            return
        }
        targetModel.setProperty(index, "selected", selected)
        selectedCount += selected ? 1 : -1
        selectedCount = Math.max(0, selectedCount)
        errorText = ""
    }

    function targetItems() {
        const items = []
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            items.push({host: String(row.host), name: String(row.deviceName || ""),
                        role: String(row.role || "")})
        }
        return items
    }

    function selectedHostList() {
        const hosts = []
        for (let i = 0; i < targetModel.count; i++) {
            if (targetModel.get(i).selected)
                hosts.push(String(targetModel.get(i).host))
        }
        return hosts
    }

    function applyHostSelection(hosts) {
        const wanted = {}
        for (let i = 0; i < hosts.length; i++)
            wanted[String(hosts[i])] = true
        // Deselect first so the maxHosts limit counts only the new selection.
        for (let j = 0; j < targetModel.count; j++) {
            if (wanted[String(targetModel.get(j).host)] !== true)
                updateSelected(j, false)
        }
        for (let k = 0; k < targetModel.count; k++) {
            if (wanted[String(targetModel.get(k).host)] === true)
                updateSelected(k, true)
        }
    }

    function selectedTargets() {
        const result = []
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            if (!row.selected)
                continue
            const networks = []
            const choices = row.networks || []
            for (let n = 0; n < collectionCount(choices); n++) {
                const choice = collectionItem(choices, n)
                if (choice.selected === true) {
                    networks.push({
                        network: choice.network,
                        wildcard: choice.wildcard,
                        area: choice.area || "0"
                    })
                }
            }
            const target = {
                host: row.host,
                router_id: String(row.routerId || "").trim(),
                networks: networks
            }
            if (protocol === "ospf")
                target.process_id = Number(row.processId)
            else
                target.as_number = Number(row.processId)
            result.push(target)
        }
        return result
    }

    function updateNetwork(hostIndex, networkIndex, field, value) {
        const row = targetModel.get(hostIndex)
        const networks = row.networks
        if (!networks || networkIndex < 0
                || networkIndex >= collectionCount(networks))
            return
        if (typeof networks.setProperty === "function") {
            networks.setProperty(networkIndex, field, value)
            return
        }
        const changedNetworks = networks.slice()
        const changed = Object.assign({}, changedNetworks[networkIndex])
        changed[field] = value
        changedNetworks[networkIndex] = changed
        targetModel.setProperty(hostIndex, "networks", changedNetworks)
    }

    function interfaceNames(interfaces) {
        const names = []
        for (let i = 0; i < collectionCount(interfaces); i++) {
            const item = collectionItem(interfaces, i)
            const name = String(item.interface_name || "").trim()
            if (name !== "")
                names.push(name)
        }
        return names.join(", ")
    }

    // Present a connected subnet once even when it belongs to several selected
    // routers. Saving still expands the choice back to each owning host so the
    // generated OSPF/EIGRP configuration remains device-local.
    function rebuildNetworkGroups() {
        const groupsByKey = ({})
        const groups = []
        for (let hostIndex = 0; hostIndex < targetModel.count; hostIndex++) {
            const row = targetModel.get(hostIndex)
            if (!row.selected)
                continue
            const choices = row.networks || []
            for (let networkIndex = 0;
                    networkIndex < collectionCount(choices); networkIndex++) {
                const choice = collectionItem(choices, networkIndex)
                const key = String(choice.network || "") + "|"
                            + String(choice.wildcard || "")
                let group = groupsByKey[key]
                if (!group) {
                    group = {
                        key: key,
                        network: String(choice.network || ""),
                        wildcard: String(choice.wildcard || ""),
                        prefixLength: Number(choice.prefix_length || 0),
                        selectedCount: 0,
                        selectedAreas: [],
                        members: []
                    }
                    groupsByKey[key] = group
                    groups.push(group)
                }
                const isSelected = choice.selected === true
                if (isSelected) {
                    group.selectedCount++
                    group.selectedAreas.push(String(choice.area || "0"))
                }
                group.members.push({
                    hostIndex: hostIndex,
                    networkIndex: networkIndex,
                    host: String(row.host || ""),
                    deviceName: String(row.deviceName || ""),
                    interfaceNames: interfaceNames(choice.interfaces),
                    selected: isSelected
                })
            }
        }

        groupedNetworkModel.clear()
        for (let i = 0; i < groups.length; i++) {
            const group = groups[i]
            let area = group.selectedAreas.length > 0
                     ? group.selectedAreas[0] : "0"
            let areaMixed = false
            for (let a = 1; a < group.selectedAreas.length; a++) {
                if (group.selectedAreas[a] !== area) {
                    areaMixed = true
                    break
                }
            }
            groupedNetworkModel.append({
                network: group.network,
                wildcard: group.wildcard,
                prefixLength: group.prefixLength,
                selected: group.selectedCount === group.members.length
                          && group.members.length > 0,
                partiallySelected: group.selectedCount > 0
                                   && group.selectedCount < group.members.length,
                area: area,
                areaMixed: areaMixed,
                memberCount: group.members.length,
                members: group.members
            })
        }
    }

    function updateNetworkGroup(groupIndex, field, value) {
        if (groupIndex < 0 || groupIndex >= groupedNetworkModel.count)
            return
        const group = groupedNetworkModel.get(groupIndex)
        if (field === "selected") {
            groupedNetworkModel.setProperty(groupIndex, "selected", Boolean(value))
            groupedNetworkModel.setProperty(groupIndex, "partiallySelected", false)
        } else if (field === "area") {
            groupedNetworkModel.setProperty(groupIndex, "area", String(value))
            groupedNetworkModel.setProperty(groupIndex, "areaMixed", false)
        }
        const members = group.members || []
        for (let i = 0; i < collectionCount(members); i++) {
            const member = collectionItem(members, i)
            if (field === "selected"
                    && typeof members.setProperty === "function")
                members.setProperty(i, "selected", Boolean(value))
            updateNetwork(Number(member.hostIndex), Number(member.networkIndex),
                          field, value)
        }
    }

    function updateNetworkGroupMember(groupIndex, memberIndex, selected) {
        if (groupIndex < 0 || groupIndex >= groupedNetworkModel.count)
            return
        const group = groupedNetworkModel.get(groupIndex)
        const members = group.members || []
        if (memberIndex < 0 || memberIndex >= collectionCount(members))
            return
        const member = collectionItem(members, memberIndex)
        if (typeof members.setProperty === "function")
            members.setProperty(memberIndex, "selected", Boolean(selected))
        updateNetwork(Number(member.hostIndex), Number(member.networkIndex),
                      "selected", Boolean(selected))

        let selectedMembers = 0
        for (let i = 0; i < collectionCount(members); i++) {
            if (collectionItem(members, i).selected === true)
                selectedMembers++
        }
        groupedNetworkModel.setProperty(
            groupIndex, "selected", selectedMembers === collectionCount(members))
        groupedNetworkModel.setProperty(
            groupIndex, "partiallySelected",
            selectedMembers > 0 && selectedMembers < collectionCount(members))
    }

    function autoAssignRouterIds(octets) {
        const values = []
        let variableIndex = -1
        for (let i = 0; i < 4; i++) {
            const value = String(octets && octets.length > i ? octets[i] : "").trim()
            if (value === "") {
                if (variableIndex >= 0) {
                    errorText = "Leave exactly one Router ID octet blank for Auto ID."
                    return false
                }
                variableIndex = i
                values.push("")
                continue
            }
            if (!/^\d+$/.test(value) || Number(value) < 0 || Number(value) > 255) {
                errorText = "Each fixed Router ID octet must be from 0 to 255."
                return false
            }
            values.push(String(Number(value)))
        }
        if (variableIndex < 0) {
            errorText = "Leave one Router ID octet blank; Auto ID fills it with 1, 2, 3..."
            return false
        }

        const selectedIndexes = []
        for (let index = 0; index < targetModel.count; index++) {
            if (targetModel.get(index).selected)
                selectedIndexes.push(index)
        }
        if (selectedIndexes.length === 0) {
            errorText = "Select hosts before assigning Router IDs."
            return false
        }
        for (let order = 0; order < selectedIndexes.length; order++) {
            const assigned = values.slice()
            assigned[variableIndex] = String(order + 1)
            targetModel.setProperty(selectedIndexes[order], "routerId", assigned.join("."))
        }
        errorText = ""
        return true
    }

    function stepValid() {
        errorText = ""
        if (stepIndex === 0 && selectedCount < 2) {
            errorText = "Select at least two hosts."
            return false
        }
        if (stepIndex === 0 && selectedCount > maxHosts) {
            errorText = "Select no more than " + maxHosts + " hosts."
            return false
        }
        if (stepIndex === 1) {
            const routerIds = ({})
            for (let i = 0; i < targetModel.count; i++) {
                const row = targetModel.get(i)
                if (!row.selected)
                    continue
                if (String(row.processId || "").trim() === "" || Number(row.processId) < 1) {
                    errorText = "Enter a valid Process ID / AS Number for " + row.host + "."
                    return false
                }
                const routerId = String(row.routerId || "").trim()
                if (routerId !== "" && routerIds[routerId]) {
                    errorText = "Router ID " + routerId + " is duplicated."
                    return false
                }
                if (routerId !== "")
                    routerIds[routerId] = true
            }
        }
        if (stepIndex === 3) {
            const targets = selectedTargets()
            for (let t = 0; t < targets.length; t++) {
                if (targets[t].networks.length === 0) {
                    errorText = "Select at least one connected network for " + targets[t].host + "."
                    return false
                }
            }
        }
        return true
    }

    function commonParameters() {
        return commonStep.parameters()
    }

    function saveGroup(pushAfterSave) {
        if (!stepValid())
            return
        const result = dbManager.saveRoutingGroup(
            protocol, selectedTargets(), commonParameters())
        notify(String(result.message || ""), result.ok ? "success"
                                                       : (result.partial ? "warning" : "error"))
        if (result.ok || result.partial) {
            const hosts = result.successful || []
            close()
            if (ownerForm && ownerForm.loadFromDatabase
                    && hosts.indexOf(String(ownerForm.currentHostIp || "")) >= 0)
                ownerForm.loadFromDatabase()
            if (pushAfterSave)
                batchDialog.openPreview(hosts, protocol)
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["1. Hosts", "2. Identity", "3. Common", "4. Networks"]
                delegate: Rectangle {
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
                        color: index === dialog.stepIndex
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
            // Pin content to the viewport; otherwise it shrinks to its implicit width.
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: Theme.spacing12

                HostSelectionBar {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 0
                    items: targetModel.count >= 0 ? dialog.targetItems() : []
                    selectedHosts: dialog.selectedCount >= 0 ? dialog.selectedHostList() : []
                    onApplySelection: hosts => dialog.applyHostSelection(hosts)
                }
                RoutingGroupHostStep {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 0
                    targetModel: targetModel
                    controller: dialog
                }
                RoutingGroupIdentityStep {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 1
                    targetModel: targetModel
                    controller: dialog
                    protocol: dialog.protocol
                }
                RoutingGroupCommonStep {
                    id: commonStep
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 2
                    protocol: dialog.protocol
                }
                RoutingGroupNetworkStep {
                    Layout.fillWidth: true
                    visible: dialog.stepIndex === 3
                    targetModel: targetModel
                    controller: dialog
                    protocol: dialog.protocol
                    networkModel: dialog.groupedNetworks
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
                visible: dialog.stepIndex < 3
                text: "Next"
                type: "Primary"
                onClicked: {
                    if (dialog.stepValid())
                        dialog.stepIndex++
                }
            }
            StandardButton {
                visible: dialog.stepIndex === 3
                text: "Save"
                icon.source: AppAssets.actionSave
                type: "Secondary"
                onClicked: dialog.saveGroup(false)
            }
            StandardButton {
                visible: dialog.stepIndex === 3
                text: "Save & Push"
                icon.source: AppAssets.actionSave
                type: "Primary"
                onClicked: dialog.saveGroup(true)
            }
        }
    }

    MultiHostViewPushDialog {
        id: batchDialog
        parent: Overlay.overlay
        controllerName: "routing"
        featureLabel: dialog.protocol.toUpperCase()
        ownerForm: dialog.ownerForm
    }
}
