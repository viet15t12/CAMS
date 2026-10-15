pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "automationWorkspace"
    color: Theme.contentBackground

    readonly property var backend:
        typeof automationManager !== "undefined" ? automationManager : null

    signal pageRequested(string key)

    property string activePage: "service"

    function pageIndex(key) {
        switch (String(key || "")) {
        case "rules": return 1
        case "editor": return 2
        case "actions": return 3
        default: return 0
        }
    }

    function editRule(ruleId, fileName) {
        ruleEditor.openRule(ruleId, fileName)
        pageRequested("editor")
    }

    function createRule() {
        ruleEditor.newRule()
        pageRequested("editor")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            objectName: "automationServiceStatusBar"
            Layout.fillWidth: true
            Layout.preferredHeight: statusRow.implicitHeight + 16
            color: root.backend !== null && root.backend.running
                   ? Theme.alertSuccessSubtle : Theme.searchBackground2
            border.width: Theme.borderWidth
            border.color: root.backend !== null && root.backend.running
                          ? Theme.alertSuccess : Theme.borderColor

            RowLayout {
                id: statusRow
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: Theme.spacing8
                anchors.bottomMargin: Theme.spacing8
                spacing: Theme.spacing8

                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: root.backend !== null && root.backend.running
                           ? Theme.alertSuccess
                           : (root.backend !== null && root.backend.state === "error"
                              ? Theme.alertError : Theme.textDisabled)
                }

                Text {
                    text: root.backend !== null && root.backend.running
                          ? "Automation Engine active"
                          : (root.backend !== null
                             ? "Automation Engine " + String(root.backend.state)
                             : "Automation Engine unavailable")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.backend !== null ? root.backend.statusMessage
                                                : "Automation backend is unavailable."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                StandardBadge {
                    text: root.backend !== null
                          ? String(root.backend.state).toUpperCase() : "UNAVAILABLE"
                    badgeColor: root.backend !== null && root.backend.running
                                ? Theme.alertSuccess
                                : (root.backend !== null && root.backend.state === "error"
                                   ? Theme.alertError : Theme.textDisabled)
                }

                StandardButton {
                    objectName: "automationGlobalServiceToggleButton"
                    text: root.backend !== null && root.backend.running ? "Stop" : "Start"
                    type: root.backend !== null && root.backend.running ? "Text" : "Primary"
                    enabled: root.backend !== null && !root.backend.busy
                    onClicked: {
                        if (root.backend.running)
                            root.backend.stop()
                        else
                            root.backend.start()
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.pageIndex(root.activePage)

            AutomationServicePage {
                objectName: "automationServicePage"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            AutomationRuleFilesPage {
                objectName: "automationRuleFilesPage"
                Layout.fillWidth: true
                Layout.fillHeight: true
                onEditRequested: function(ruleId, fileName) {
                    root.editRule(ruleId, fileName)
                }
                onCreateRequested: function() {
                    root.createRule()
                }
            }

            AutomationRuleEditorPage {
                id: ruleEditor
                objectName: "automationRuleEditorPage"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            AutomationActionsPage {
                objectName: "automationActionsPage"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
