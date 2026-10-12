pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground

    signal editRequested(string ruleId, string fileName)
    signal createRequested()

    readonly property var backend:
        typeof automationManager !== "undefined" ? automationManager : null
    property var rules: []
    property string pendingDeleteRuleId: ""
    property string pendingDeleteRuleFile: ""
    property string resultMessage: ""
    property bool resultOk: true

    function reloadRules() {
        rules = backend !== null ? backend.getRules() : []
    }

    function showResult(result, fallback) {
        resultOk = result && result.ok === true
        resultMessage = result && result.message
            ? String(result.message) : fallback
    }

    Component.onCompleted: reloadRules()

    Connections {
        target: root.backend
        function onRulesChanged() { root.reloadRules() }
    }

    FileDialog {
        id: importDialog
        title: "Import automation rule"
        nameFilters: ["CAMS automation rule (*.json)"]
        onAccepted: {
            const result = root.backend.importRule(String(selectedFile))
            root.showResult(result, "Unable to import the rule.")
        }
    }

    Dialog {
        id: deleteDialog
        title: "Delete automation rule?"
        modal: true
        width: 460
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            const result = root.backend.deleteRule(root.pendingDeleteRuleFile)
            root.showResult(result, "Unable to delete the rule.")
            root.pendingDeleteRuleId = ""
            root.pendingDeleteRuleFile = ""
        }
        onRejected: {
            root.pendingDeleteRuleId = ""
            root.pendingDeleteRuleFile = ""
        }
        contentItem: Text {
            text: "This removes the JSON rule file from the active workspace. Existing audit actions are retained."
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            wrapMode: Text.WordWrap
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
                    text: "Rule Files"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Manage the validated JSON rule files stored in the active workspace."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }
            }
            StandardButton {
                text: "Reload"
                type: "Text"
                icon.source: AppAssets.actionRefresh
                onClicked: root.reloadRules()
            }
            StandardButton {
                text: "Import JSON"
                icon.source: AppAssets.actionUpload
                enabled: root.backend !== null
                onClicked: importDialog.open()
            }
            StandardButton {
                objectName: "automationCreateRuleButton"
                text: "Write Rule"
                type: "Primary"
                icon.source: AppAssets.actionEdit
                enabled: root.backend !== null
                onClicked: root.createRequested()
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            visible: root.resultMessage !== ""
            message: root.resultMessage
            severity: root.resultOk ? "success" : "error"
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
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.spacing8

                    Text {
                        Layout.fillWidth: true
                        visible: root.rules.length === 0
                        text: "No rule files in this workspace. Import JSON or open Rule Editor to create one."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.rules
                        delegate: Rectangle {
                            id: ruleCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: ruleRow.implicitHeight + 20
                            radius: Theme.radiusSmall
                            color: Theme.contentBackground
                            border.width: Theme.borderWidth
                            border.color: modelData.valid
                                          ? Theme.borderColor : Theme.alertError

                            RowLayout {
                                id: ruleRow
                                anchors.fill: parent
                                anchors.margins: Theme.spacing8
                                spacing: Theme.spacing8

                                StandardCheckBox {
                                    text: ""
                                    checked: Boolean(ruleCard.modelData.enabled)
                                    enabled: root.backend !== null
                                             && Boolean(ruleCard.modelData.valid)
                                    onToggled: {
                                        const result = root.backend.setRuleEnabled(
                                            String(ruleCard.modelData.file_name), checked
                                        )
                                        root.showResult(result, "Unable to update the rule.")
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: String(ruleCard.modelData.name)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: ruleCard.modelData.valid
                                              ? "%1 → %2 · every %3s · %4"
                                                   .arg(ruleCard.modelData.event_type)
                                                   .arg(ruleCard.modelData.action_type)
                                                   .arg(ruleCard.modelData.interval_seconds)
                                                   .arg(ruleCard.modelData.file_name)
                                              : String(ruleCard.modelData.error)
                                        color: ruleCard.modelData.valid
                                               ? Theme.textSecondary : Theme.alertError
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                                StandardButton {
                                    text: "Edit"
                                    type: "Text"
                                    icon.source: AppAssets.actionEdit
                                    enabled: Boolean(ruleCard.modelData.valid)
                                    onClicked: root.editRequested(
                                        String(ruleCard.modelData.id),
                                        String(ruleCard.modelData.file_name)
                                    )
                                }
                                StandardButton {
                                    text: "Delete"
                                    type: "Text"
                                    icon.source: AppAssets.actionDelete
                                    onClicked: {
                                        root.pendingDeleteRuleId = String(ruleCard.modelData.id)
                                        root.pendingDeleteRuleFile = String(ruleCard.modelData.file_name)
                                        deleteDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
