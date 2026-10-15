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

    function actionSummary(rule) {
        if (!rule || !rule.valid)
            return ""
        if (String(rule.action_type) === "interface.admin-state") {
            const verb = rule.action_enabled === true ? "No shutdown" : "Shutdown"
            return "%1 %2".arg(verb).arg(String(rule.target || "event interface"))
        }
        if (String(rule.action_type) === "ssh.cli") {
            return "SSH %1 · %2 command(s)"
                .arg(String(rule.action_mode || "config"))
                .arg(Number(rule.command_count || 0))
        }
        return "%1 · %2".arg(String(rule.action_type)).arg(String(rule.target || "event data"))
    }

    function importRuleFile(fileUrl) {
        if (backend === null)
            return
        const result = backend.importRule(String(fileUrl || ""))
        showResult(result, "Unable to import the rule.")
        if (result && result.ok) {
            editRequested(String(result.id || ""), String(result.file_name || ""))
        }
    }

    Component.onCompleted: reloadRules()

    Connections {
        target: root.backend
        function onRulesChanged() { root.reloadRules() }
    }

    FileDialog {
        id: importDialog
        title: "Import automation rule"
        nameFilters: [
            "CAMS automation rule (*.rule.cams)",
            "Legacy JSON automation rule (*.json)"
        ]
        onAccepted: root.importRuleFile(selectedFile)
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
            text: "This removes the .rule.cams file from the active workspace. Existing audit actions are retained."
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
                    text: "Enable, inspect and edit validated .rule.cams files. Use Quick Builder for fixed-interface SSH actions."
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
                objectName: "automationImportRuleButton"
                text: "Import .rule.cams"
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing8
                        Text {
                            Layout.fillWidth: true
                            text: "%1 rule(s) in the active workspace".arg(root.rules.length)
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        StandardBadge {
                            text: root.backend !== null && root.backend.running
                                  ? "ENGINE ACTIVE" : "ENGINE STOPPED"
                            badgeColor: root.backend !== null && root.backend.running
                                        ? Theme.alertSuccess : Theme.textDisabled
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.rules.length === 0
                        text: "No rule files in this workspace. Import .rule.cams or open Rule Editor to create one."
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
                            implicitHeight: ruleContent.implicitHeight + 20
                            radius: Theme.radiusSmall
                            color: Theme.contentBackground
                            border.width: Theme.borderWidth
                            border.color: modelData.valid
                                          ? Theme.borderColor : Theme.alertError

                            ColumnLayout {
                                id: ruleContent
                                anchors.fill: parent
                                anchors.margins: Theme.spacing8
                                spacing: Theme.spacing4

                                RowLayout {
                                    Layout.fillWidth: true
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

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(ruleCard.modelData.name)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    StandardBadge {
                                        text: ruleCard.modelData.valid
                                              ? String(ruleCard.modelData.mode).toUpperCase()
                                              : "INVALID"
                                        badgeColor: !ruleCard.modelData.valid
                                                    ? Theme.alertError
                                                    : (String(ruleCard.modelData.mode) === "auto"
                                                       ? Theme.alertSuccess : Theme.alertWarning)
                                    }

                                    StandardBadge {
                                        text: ruleCard.modelData.valid
                                              ? "V%1 · %2"
                                                   .arg(ruleCard.modelData.version)
                                                   .arg(String(ruleCard.modelData.transport).toUpperCase())
                                              : ""
                                        badgeColor: Theme.accentEmphasis
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

                                Text {
                                    Layout.fillWidth: true
                                    text: ruleCard.modelData.valid
                                          ? "%1 → %2 · cooldown %3s · max %4/hour · scan %5s"
                                               .arg(ruleCard.modelData.event_type)
                                               .arg(root.actionSummary(ruleCard.modelData))
                                               .arg(ruleCard.modelData.cooldown_seconds)
                                               .arg(ruleCard.modelData.max_actions_per_hour)
                                               .arg(ruleCard.modelData.interval_seconds)
                                          : String(ruleCard.modelData.error)
                                    color: ruleCard.modelData.valid
                                           ? Theme.textSecondary : Theme.alertError
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: String(ruleCard.modelData.file_name)
                                    color: Theme.textDisabled
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
