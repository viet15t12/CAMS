pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

FormSection {
    id: root
    required property var targetModel
    required property var controller
    required property string protocol
    readonly property bool compactColumns: width < 480
    readonly property real networkColumnWidth: Math.ceil(networkLabelMetrics.width)
                                               + Theme.checkboxSize
                                               + Theme.spacing8 + Theme.spacing12
    readonly property real areaColumnWidth: Math.max(100, Theme.inputMinimumWidth)

    TextMetrics {
        id: networkLabelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        text: "255.255.255.255 /32"
    }
    title: protocol === "ospf"
           ? "Connected networks and OSPF area"
           : "Connected networks"
    helpText: protocol === "ospf"
              ? "Select each connected subnet that should run OSPF. The interface list shows where that subnet was discovered. Area assigns the selected subnet to an OSPF area; use 0 for the backbone."
              : "Select each connected subnet that should participate in EIGRP. The generated network statement enables EIGRP on matching interfaces and advertises the connected subnet."

    function interfaceNames(interfaces) {
        if (!interfaces)
            return ""
        const count = typeof interfaces.count === "number"
                    ? interfaces.count : (interfaces.length || 0)
        const names = []
        for (let i = 0; i < count; i++) {
            const item = typeof interfaces.get === "function"
                       ? interfaces.get(i) : interfaces[i]
            names.push(String(item.interface_name || ""))
        }
        return names.filter(name => name !== "").join(", ")
    }

    property string bulkFeedback: ""
    // Nested network rows do not notify their delegates; bump this to resync them.
    property int revision: 0

    // Bulk actions over the networks of every selected host. decide(choice, hostIndex)
    // returns the new selected state, or undefined to leave that network untouched.
    function applyToNetworks(decide) {
        let changed = 0
        for (let h = 0; h < targetModel.count; h++) {
            const row = targetModel.get(h)
            if (!row.selected)
                continue
            const networks = row.networks
            const count = typeof networks.count === "number" ? networks.count : (networks.length || 0)
            for (let n = 0; n < count; n++) {
                const choice = typeof networks.get === "function" ? networks.get(n) : networks[n]
                const wanted = decide(choice, h)
                if (wanted !== undefined && Boolean(choice.selected) !== wanted) {
                    controller.updateNetwork(h, n, "selected", wanted)
                    changed++
                }
            }
        }
        revision++
        return changed
    }

    // Delegate modelData is a snapshot; read the live row the way selectedTargets() does.
    function networkAt(hostIndex, networkIndex) {
        const networks = targetModel.get(hostIndex).networks
        return typeof networks.get === "function" ? networks.get(networkIndex) : networks[networkIndex]
    }

    // One item per interface so "Loopback*" matches any interface that owns the subnet.
    function matchedNetworks(hostIndex) {
        const networks = targetModel.get(hostIndex).networks
        const count = typeof networks.count === "number" ? networks.count : (networks.length || 0)
        const items = []
        for (let n = 0; n < count; n++) {
            const choice = typeof networks.get === "function" ? networks.get(n) : networks[n]
            const names = interfaceNames(choice.interfaces).split(", ")
            for (let i = 0; i < names.length; i++)
                items.push({host: String(choice.network), name: names[i]})
        }
        return HostPattern.select(items, networkPatternField.text)
    }

    function applyNetworkPattern(excluding) {
        const perHost = {}
        for (let h = 0; h < targetModel.count; h++) {
            if (!targetModel.get(h).selected)
                continue
            const result = matchedNetworks(h)
            if (result.error !== "") {
                bulkFeedback = result.error
                return
            }
            perHost[h] = result.hosts
        }
        const changed = applyToNetworks((choice, h) => {
            const hit = perHost[h].indexOf(String(choice.network)) >= 0
            return excluding ? (hit ? false : undefined) : hit
        })
        bulkFeedback = (excluding ? "Excluded" : "Selected") + " matching networks: "
                + changed + " change(s)."
    }

    function setAreaForSelected() {
        const area = areaBulkField.text.trim()
        if (area === "") {
            bulkFeedback = "Type an area first, for example 0 or 10."
            return
        }
        let changed = 0
        for (let h = 0; h < targetModel.count; h++) {
            const row = targetModel.get(h)
            if (!row.selected)
                continue
            const networks = row.networks
            const count = typeof networks.count === "number" ? networks.count : (networks.length || 0)
            for (let n = 0; n < count; n++) {
                const choice = typeof networks.get === "function" ? networks.get(n) : networks[n]
                if (choice.selected === true) {
                    controller.updateNetwork(h, n, "area", area)
                    changed++
                }
            }
        }
        revision++
        bulkFeedback = "Area " + area + " set on " + changed + " selected network(s)."
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing4
        StandardTextField {
            id: networkPatternField
            objectName: "routingGroupNetworkPatternField"
            Layout.fillWidth: true
            Layout.minimumWidth: 140
            placeholderText: "192.168.0.0/16  ·  10.1.12.0  ·  Loopback*  ·  Gi*0/1.*"
            onAccepted: root.applyNetworkPattern(false)
        }
        StandardButton {
            text: "Select"
            tooltip: "Select only the networks matching the pattern on every host (Enter)."
            onClicked: root.applyNetworkPattern(false)
        }
        StandardButton {
            text: "Exclude"
            tooltip: "Clear the networks matching the pattern on every host."
            onClicked: root.applyNetworkPattern(true)
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing4
        StandardButton {
            text: "All"
            type: "Text"
            onClicked: root.bulkFeedback = "Selected " + root.applyToNetworks(() => true) + " network(s)."
        }
        StandardButton {
            text: "None"
            type: "Text"
            onClicked: root.bulkFeedback = "Cleared " + root.applyToNetworks(() => false) + " network(s)."
        }
        StandardTextField {
            id: areaBulkField
            objectName: "routingGroupBulkAreaField"
            visible: root.protocol === "ospf"
            width: root.areaColumnWidth
            placeholderText: "Area"
            onAccepted: root.setAreaForSelected()
        }
        StandardButton {
            visible: root.protocol === "ospf"
            text: "Set area"
            tooltip: "Apply this area to every selected network."
            onClicked: root.setAreaForSelected()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.bulkFeedback !== ""
        text: root.bulkFeedback
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.targetModel
        delegate: ColumnLayout {
            id: hostNetworkBlock
            required property int index
            required property string host
            required property bool selected
            required property var networks
            property int hostIndex: index
            visible: selected
            Layout.fillWidth: true
            Text {
                text: host
                color: Theme.accentColor
                font.family: Theme.fontFamily
                font.bold: true
            }
            Repeater {
                model: networks
                delegate: GridLayout {
                    id: networkRow
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    columns: root.compactColumns ? 2 : 3
                    Connections {
                        target: root
                        function onRevisionChanged() {
                            const live = root.networkAt(hostNetworkBlock.hostIndex, networkRow.index)
                            networkCheck.checked = live.selected === true
                            areaField.text = live.area || "0"
                        }
                    }
                    StandardCheckBox {
                        id: networkCheck
                        Layout.columnSpan: root.compactColumns ? 2 : 1
                        Layout.fillWidth: root.compactColumns
                        Layout.minimumWidth: root.compactColumns ? 0 : root.networkColumnWidth
                        Layout.preferredWidth: root.networkColumnWidth
                        Layout.maximumWidth: root.compactColumns ? Infinity : root.networkColumnWidth
                        text: modelData.network + " /" + modelData.prefix_length
                        checked: modelData.selected === true
                        onToggled: root.controller.updateNetwork(
                                       hostNetworkBlock.hostIndex,
                                       index, "selected", checked)
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        elide: Text.ElideRight
                        text: root.interfaceNames(modelData.interfaces)
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                    }
                    StandardTextField {
                        id: areaField
                        objectName: "routingGroupNetworkAreaField"
                        visible: root.protocol === "ospf"
                        // Override ColumnLayout's implicit stretch and shared input minimum.
                        Layout.fillWidth: false
                        Layout.minimumWidth: root.areaColumnWidth
                        Layout.preferredWidth: root.areaColumnWidth
                        Layout.maximumWidth: root.areaColumnWidth
                        labelText: "Area"
                        text: modelData.area || "0"
                        onTextEdited: value => root.controller.updateNetwork(
                                          hostNetworkBlock.hostIndex,
                                          index, "area", value)
                    }
                }
            }
        }
    }
}
