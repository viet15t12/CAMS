import QtQuick
import QtQuick.Controls.Basic
import UI

ApplicationWindow {
    width: 1000
    height: 840
    visible: true
    property alias dialog: networkDialog

    RoutingGroupDialog {
        id: networkDialog
        parent: Overlay.overlay
    }

    Component.onCompleted: {
        const networks = [
            {network: "192.168.122.0", prefix_length: 24, wildcard: "0.0.0.255",
             interfaces: [{interface_name: "GigabitEthernet0/0"}]},
            {network: "192.168.10.0", prefix_length: 24, wildcard: "0.0.0.255",
             interfaces: [{interface_name: "GigabitEthernet0/1.10"}]},
            {network: "10.1.12.0", prefix_length: 24, wildcard: "0.0.0.255",
             interfaces: [{interface_name: "GigabitEthernet0/2"},
                          {interface_name: "GigabitEthernet0/3.1234"}]},
            {network: "1.1.1.0", prefix_length: 24, wildcard: "0.0.0.255",
             interfaces: [{interface_name: "Loopback0"}]}
        ]
        networkDialog.populateTargets([
            {host: "192.168.122.104", device_name: "R1", networks: networks},
            {host: "192.168.122.105", device_name: "R2", networks: networks},
            {host: "192.168.122.106", device_name: "R3", networks: networks}
        ])
        for (let i = 0; i < 3; ++i) {
            networkDialog.updateSelected(i, true)
            networkDialog.updateNetwork(i, 0, "selected", true)
            networkDialog.updateNetwork(i, 0, "area", "7")
        }
        networkDialog.stepIndex = 3
        networkDialog.open()
    }
}
