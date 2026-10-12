pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground

    readonly property var backend:
        typeof automationManager !== "undefined" ? automationManager : null
    property string selectedRuleId: ""
    property string selectedRuleFile: ""
    property string resultMessage: ""
    property bool resultOk: true

    function showResult(result, fallback) {
        resultOk = result && result.ok === true
        resultMessage = result && result.message
            ? String(result.message) : fallback
    }

    function newRule() {
        selectedRuleId = ""
        selectedRuleFile = ""
        ruleEditor.text = ""
        resultMessage = ""
        ruleEditor.forceActiveFocus()
    }

    function loadIcmpExample() {
        selectedRuleId = ""
        selectedRuleFile = ""
        ruleEditor.text = backend !== null ? backend.sampleIcmpRule() : ""
        resultMessage = "Example loaded disabled. Review it, then save and enable it explicitly."
        resultOk = true
        ruleEditor.forceActiveFocus()
    }

    function openRule(ruleId, fileName) {
        if (backend === null)
            return
        const result = backend.getRule(String(fileName || ""))
        showResult(result, "Unable to load the selected rule.")
        if (result && result.ok) {
            selectedRuleId = String(ruleId || "")
            selectedRuleFile = String(fileName || "")
            ruleEditor.text = String(result.text || "")
            ruleEditor.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing4
                Text {
                    text: root.selectedRuleId === ""
                          ? "Rule Editor" : "Edit " + root.selectedRuleId
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.selectedRuleFile === ""
                          ? "Write a strict version 1 JSON rule. New rules remain dry-run only."
                          : "File: " + root.selectedRuleFile
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: root.selectedRuleFile === ""
                                 ? Theme.fontFamily : Theme.monoFontFamily
                    elide: Text.ElideMiddle
                }
            }

            StandardButton {
                text: "New"
                type: "Text"
                icon.source: AppAssets.actionClear
                onClicked: root.newRule()
            }
            StandardButton {
                objectName: "automationIcmpSampleButton"
                text: "ICMP DoS Example"
                icon.source: AppAssets.actionCopy
                enabled: root.backend !== null
                onClicked: root.loadIcmpExample()
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            message: "Rules cannot contain arbitrary RESTCONF URLs, HTTP payloads, commands, or SQL."
            severity: "info"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.searchBackground2
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                clip: true
                TextArea {
                    id: ruleEditor
                    objectName: "automationRuleEditor"
                    width: Math.max(parent.availableWidth, contentWidth)
                    height: Math.max(parent.availableHeight, contentHeight)
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    color: Theme.textPrimary
                    selectedTextColor: Theme.selectionForeground
                    selectionColor: Theme.selectionBackground
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    background: Rectangle { color: "transparent" }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.resultMessage !== ""
            text: root.resultMessage
            color: root.resultOk ? Theme.alertSuccess : Theme.alertError
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StandardButton {
                objectName: "automationSaveRuleButton"
                text: "Validate & Save"
                type: "Primary"
                icon.source: AppAssets.actionSave
                enabled: root.backend !== null && ruleEditor.text.trim() !== ""
                onClicked: {
                    const result = root.backend.saveRule(ruleEditor.text)
                    root.showResult(result, "Unable to save the rule.")
                    if (result && result.ok) {
                        root.selectedRuleId = String(result.id)
                        root.selectedRuleFile = String(result.id) + ".json"
                    }
                }
            }
        }
    }
}
