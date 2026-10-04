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
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    columns: root.compactColumns ? 2 : 3
                    StandardCheckBox {
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
