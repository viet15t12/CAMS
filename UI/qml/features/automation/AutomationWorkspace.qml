pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "automationWorkspace"
    color: Theme.contentBackground

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

    StackLayout {
        anchors.fill: parent
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
