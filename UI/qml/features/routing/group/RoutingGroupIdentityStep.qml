pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

FormSection {
    id: root
    required property var targetModel
    required property var controller
    required property string protocol
    title: "Per-host Process ID and Router ID"
    helpText: protocol === "ospf"
              ? "Process ID: local OSPF process number from 1 to 65535; it may differ between routers.\n\nAuto ID: fill three octets and leave exactly one blank. The blank position is assigned 1, 2, 3... in selected-host order. For example, 1 · 1 · 1 · [blank] creates 1.1.1.1, 1.1.1.2...\n\nRouter ID: optional unique IPv4-form identifier for each router. Do not reuse a Router ID within the OSPF domain."
              : "AS Number: EIGRP autonomous-system number. All intended neighbors must use the same AS number.\n\nAuto ID: fill three octets and leave exactly one blank. The blank position is assigned 1, 2, 3... in selected-host order.\n\nRouter ID: optional unique IPv4-form identifier for each router."

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing8

        Text {
            text: "Router ID template"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
        StandardTextField {
            id: octet1
            objectName: "routingGroupAutoIdOctet1"
            Layout.minimumWidth: 52
            Layout.preferredWidth: 64
            Layout.maximumWidth: 72
            text: "1"
            placeholderText: "x"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: 255 }
            horizontalAlignment: TextInput.AlignHCenter
        }
        Text { text: "."; color: Theme.textSecondary }
        StandardTextField {
            id: octet2
            objectName: "routingGroupAutoIdOctet2"
            Layout.minimumWidth: 52
            Layout.preferredWidth: 64
            Layout.maximumWidth: 72
            text: "1"
            placeholderText: "x"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: 255 }
            horizontalAlignment: TextInput.AlignHCenter
        }
        Text { text: "."; color: Theme.textSecondary }
        StandardTextField {
            id: octet3
            objectName: "routingGroupAutoIdOctet3"
            Layout.minimumWidth: 52
            Layout.preferredWidth: 64
            Layout.maximumWidth: 72
            text: "1"
            placeholderText: "x"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: 255 }
            horizontalAlignment: TextInput.AlignHCenter
        }
        Text { text: "."; color: Theme.textSecondary }
        StandardTextField {
            id: octet4
            objectName: "routingGroupAutoIdOctet4"
            Layout.minimumWidth: 52
            Layout.preferredWidth: 64
            Layout.maximumWidth: 72
            placeholderText: "x"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: 255 }
            horizontalAlignment: TextInput.AlignHCenter
        }
        StandardButton {
            objectName: "routingGroupAutoIdButton"
            text: "Auto ID"
            type: "Secondary"
            onClicked: root.controller.autoAssignRouterIds(
                           [octet1.text, octet2.text, octet3.text, octet4.text])
        }
        Item { Layout.fillWidth: true }
    }

    Text {
        Layout.fillWidth: true
        text: "Leave one octet blank (x). Auto ID replaces that position with the selected router number."
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeCaption
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.targetModel
        delegate: RowLayout {
            required property int index
            required property string host
            required property bool selected
            required property string processId
            required property string routerId
            visible: selected
            Layout.fillWidth: true
            Text {
                Layout.preferredWidth: 160
                text: host
                color: Theme.textPrimary
                font.family: Theme.fontFamily
            }
            StandardTextField {
                Layout.fillWidth: true
                labelText: root.protocol === "ospf" ? "Process ID" : "AS Number"
                text: processId
                inputMethodHints: Qt.ImhDigitsOnly
                onTextEdited: value => root.targetModel.setProperty(
                                  index, "processId", value)
            }
            StandardNetworkField {
                Layout.fillWidth: true
                inputKind: "ipv4"
                labelText: "Router ID (optional)"
                text: routerId
                onTextEdited: value => root.targetModel.setProperty(
                                  index, "routerId", value)
            }
        }
    }
}
