pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

// Shared bulk-selection row for device lists: pattern box plus All/None/Invert.
// The owner applies `applySelection(hosts)` as the complete new selection.
ColumnLayout {
    id: root
    objectName: "hostSelectionBar"

    property var items: []          // [{host, name, role}]
    readonly property bool hasRoles: (items || []).some(item => String(item.role || "") !== "")
    property var selectedHosts: []  // hosts currently selected, for Invert
    property string feedback: ""
    property bool feedbackIsError: false

    signal applySelection(var hosts)

    spacing: Theme.spacing4

    function allHosts() {
        return (items || []).map(item => String(item.host))
    }

    function emitSelection(hosts, label) {
        feedbackIsError = false
        feedback = label + ": " + hosts.length + " of " + (items || []).length + " device(s) selected."
        applySelection(hosts)
    }

    // excluding=false: select exactly the matches. excluding=true: drop the matches
    // from the current selection, or from every host when nothing is selected yet.
    function applyPattern(excluding) {
        const result = HostPattern.select(items, patternField.text)
        if (result.error !== "") {
            feedbackIsError = true
            feedback = result.error
            return
        }
        if (!excluding) {
            emitSelection(result.hosts, "Selected")
            return
        }
        const matched = {}
        for (let i = 0; i < result.hosts.length; i++)
            matched[result.hosts[i]] = true
        const base = (selectedHosts || []).length > 0
                ? selectedHosts.map(host => String(host)) : allHosts()
        const kept = base.filter(host => matched[host] !== true)
        emitSelection(kept, "Excluded " + (base.length - kept.length))
    }

    function invert() {
        const current = {}
        const selected = selectedHosts || []
        for (let i = 0; i < selected.length; i++)
            current[String(selected[i])] = true
        emitSelection(allHosts().filter(host => current[host] !== true), "Inverted")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing4

        StandardTextField {
            id: patternField
            objectName: "hostPatternField"
            Layout.fillWidth: true
            Layout.minimumWidth: 140
            placeholderText: "R1-R10  ·  SW1-20  ·  router  ·  10.0.0.0/26  ·  SW*"
            onAccepted: root.applyPattern(false)
        }
        StandardButton {
            objectName: "hostPatternApplyButton"
            text: "Select"
            tooltip: "Select only the devices you typed (Enter)."
            onClicked: root.applyPattern(false)
        }
        StandardButton {
            objectName: "hostPatternExcludeButton"
            text: "Exclude"
            tooltip: "Remove the devices you typed from the selection. With nothing selected, keeps every other device."
            onClicked: root.applyPattern(true)
        }
    }

    // Flow wraps the quick buttons so the bar never widens narrow columns or the sidebar.
    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing4

        StandardButton {
            objectName: "hostSelectAllButton"
            text: "All"
            type: "Text"
            onClicked: root.emitSelection(root.allHosts(), "All")
        }
        StandardButton {
            objectName: "hostSelectNoneButton"
            text: "None"
            type: "Text"
            onClicked: root.emitSelection([], "None")
        }
        StandardButton {
            objectName: "hostSelectRoutersButton"
            visible: root.hasRoles
            text: "Routers"
            type: "Text"
            onClicked: root.emitSelection(HostPattern.select(root.items, "router").hosts, "Routers")
        }
        StandardButton {
            objectName: "hostSelectSwitchesButton"
            visible: root.hasRoles
            text: "Switches"
            type: "Text"
            onClicked: root.emitSelection(HostPattern.select(root.items, "switch").hosts, "Switches")
        }
        StandardButton {
            objectName: "hostSelectInvertButton"
            text: "Invert"
            type: "Text"
            onClicked: root.invert()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.feedback !== ""
        text: root.feedback
        color: root.feedbackIsError ? Theme.alertError : Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
