pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

FormSection {
    id: root
    required property var targetModel
    required property var controller
    required property string protocol
    required property var networkModel
    readonly property bool compactColumns: width < 620
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
              ? "Each connected subnet appears once. Selecting it applies the same Area to every selected router that owns that subnet; CAMS still generates a separate OSPF network statement on each device. Use Details to verify router and interface membership."
              : "Each connected subnet appears once. Selecting it enables EIGRP on every selected router that owns that subnet. Use Details to verify router and interface membership."

    onVisibleChanged: {
        if (visible)
            controller.rebuildNetworkGroups()
    }

    property string bulkFeedback: ""

    function listCount(list) {
        return !list ? 0 : (typeof list.count === "number" ? list.count : (list.length || 0))
    }

    function listItem(list, index) {
        return typeof list.get === "function" ? list.get(index) : list[index]
    }

    // decide(group) returns the new selected state, or undefined to leave it.
    // Rebuilding afterwards resyncs every row, including ones the user edited.
    function applyToGroups(decide) {
        let changed = 0
        for (let i = 0; i < listCount(networkModel); i++) {
            const group = listItem(networkModel, i)
            const wanted = decide(group)
            if (wanted !== undefined
                    && (Boolean(group.selected) !== wanted || group.partiallySelected)) {
                controller.updateNetworkGroup(i, "selected", wanted)
                changed++
            }
        }
        controller.rebuildNetworkGroups()
        return changed
    }

    // One item per interface so "Loopback*" matches any interface owning the subnet.
    function applyNetworkPattern(excluding) {
        const items = []
        for (let i = 0; i < listCount(networkModel); i++) {
            const group = listItem(networkModel, i)
            for (let m = 0; m < listCount(group.members); m++) {
                const names = String(listItem(group.members, m).interfaceNames || "").split(", ")
                for (let n = 0; n < names.length; n++)
                    items.push({host: String(group.network), name: names[n]})
            }
        }
        const result = HostPattern.select(items, networkPatternField.text)
        if (result.error !== "") {
            bulkFeedback = result.error
            return
        }
        const changed = applyToGroups(group => {
            const hit = result.hosts.indexOf(String(group.network)) >= 0
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
        for (let i = 0; i < listCount(networkModel); i++) {
            const group = listItem(networkModel, i)
            if (group.selected || group.partiallySelected) {
                controller.updateNetworkGroup(i, "area", area)
                changed++
            }
        }
        controller.rebuildNetworkGroups()
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
            tooltip: "Select only the networks matching the pattern (Enter)."
            onClicked: root.applyNetworkPattern(false)
        }
        StandardButton {
            text: "Exclude"
            tooltip: "Clear the networks matching the pattern."
            onClicked: root.applyNetworkPattern(true)
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing4
        StandardButton {
            text: "All"
            type: "Text"
            onClicked: root.bulkFeedback = "Selected " + root.applyToGroups(() => true) + " network(s)."
        }
        StandardButton {
            text: "None"
            type: "Text"
            onClicked: root.bulkFeedback = "Cleared " + root.applyToGroups(() => false) + " network(s)."
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
        model: root.networkModel
        delegate: ColumnLayout {
            id: networkBlock
            required property int index
            required property var modelData
            property bool detailsVisible: false
            Layout.fillWidth: true
            spacing: Theme.spacing8

            GridLayout {
                Layout.fillWidth: true
                columns: root.compactColumns ? 2 : 4
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardCheckBox {
                    Layout.columnSpan: root.compactColumns ? 2 : 1
                    Layout.fillWidth: root.compactColumns
                    Layout.minimumWidth: root.compactColumns ? 0 : root.networkColumnWidth
                    Layout.preferredWidth: root.networkColumnWidth
                    Layout.maximumWidth: root.compactColumns ? Infinity : root.networkColumnWidth
                    text: networkBlock.modelData.network + " /"
                          + networkBlock.modelData.prefixLength
                    tristate: true
                    checkState: networkBlock.modelData.partiallySelected
                                ? Qt.PartiallyChecked
                                : (networkBlock.modelData.selected
                                   ? Qt.Checked : Qt.Unchecked)
                    nextCheckState: function() {
                        return checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
                    }
                    onClicked: root.controller.updateNetworkGroup(
                                   networkBlock.index, "selected",
                                   checkState === Qt.Checked)
                }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.columnSpan: root.compactColumns ? 2 : 1
                    text: networkBlock.modelData.memberCount + " device"
                          + (networkBlock.modelData.memberCount === 1 ? "" : "s")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                StandardTextField {
                    objectName: "routingGroupNetworkAreaField"
                    visible: root.protocol === "ospf"
                    enabled: networkBlock.modelData.selected
                             || networkBlock.modelData.partiallySelected
                    Layout.fillWidth: false
                    Layout.minimumWidth: root.areaColumnWidth
                    Layout.preferredWidth: root.areaColumnWidth
                    Layout.maximumWidth: root.areaColumnWidth
                    labelText: networkBlock.modelData.areaMixed ? "Area (mixed)" : "Area"
                    text: networkBlock.modelData.area || "0"
                    onTextEdited: value => root.controller.updateNetworkGroup(
                                      networkBlock.index, "area", value)
                }
                StandardButton {
                    objectName: "routingGroupNetworkDetailsButton"
                    Layout.alignment: Qt.AlignBottom
                    text: networkBlock.detailsVisible ? "Hide details" : "Details"
                    type: "TextIcon"
                    checkable: true
                    checked: networkBlock.detailsVisible
                    icon.source: networkBlock.detailsVisible
                                 ? AppAssets.navigationChevronUp
                                 : AppAssets.navigationChevronDown
                    onClicked: networkBlock.detailsVisible = !networkBlock.detailsVisible
                }
            }

            Rectangle {
                visible: networkBlock.detailsVisible
                Layout.fillWidth: true
                implicitHeight: detailLayout.implicitHeight + Theme.spacing12 * 2
                color: Theme.contentSurface
                border.color: Theme.borderColor
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall

                ColumnLayout {
                    id: detailLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacing12
                    spacing: Theme.spacing8

                    Repeater {
                        model: networkBlock.modelData.members
                        delegate: RowLayout {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.spacing12

                            StandardCheckBox {
                                Layout.preferredWidth: 220
                                Layout.maximumWidth: 220
                                text: modelData.deviceName !== ""
                                      ? modelData.deviceName + " · " + modelData.host
                                      : modelData.host
                                checked: modelData.selected === true
                                onClicked: root.controller.updateNetworkGroupMember(
                                               networkBlock.index, index, checked)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.interfaceNames !== ""
                                      ? modelData.interfaceNames
                                      : "No interface name"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.borderWidth
                color: Theme.borderColor
            }
        }
    }
}
