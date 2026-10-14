pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "batchPushSettings"
    color: Theme.contentBackground
    property var backend: typeof dbManager !== "undefined" ? dbManager : null
    property string resultMessage: ""

    function syncFields() {
        if (!backend)
            return
        const policy = backend.batchPushPolicy()
        concurrencySpin.value = policy.maxConcurrentHosts
        canarySpin.value = policy.canaryHosts
        failSpin.value = policy.maxFailPercent
        resultMessage = ""
    }

    function save() {
        if (!backend)
            return
        const policy = backend.setBatchPushPolicy(
            concurrencySpin.value, canarySpin.value, failSpin.value)
        resultMessage = "Saved. Next batch Push: " + policy.maxConcurrentHosts
                + " devices at a time, first " + policy.canaryHosts
                + " as a test wave, stop above " + policy.maxFailPercent + "% failures."
    }

    onVisibleChanged: if (visible) syncFields()
    Component.onCompleted: syncFields()

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.availableWidth
            spacing: Theme.spacing16

            Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.spacing8 }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: Theme.spacing4
                Text {
                    text: "Batch Push"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Control how View & Push sends configuration to many devices at once "
                          + "(Routing Group, FHRP, VTP, EtherChannel, Syslog Group)."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: policyLayout.implicitHeight + 24
                color: Theme.searchBackground2
                radius: Theme.borderRadius
                border.width: Theme.borderWidth
                border.color: Theme.borderColor

                ColumnLayout {
                    id: policyLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 12

                        StandardSpinBox {
                            id: concurrencySpin
                            objectName: "batchConcurrencySpin"
                            Layout.preferredWidth: 220
                            labelText: "Devices in parallel"
                            from: 1
                            to: 50
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "How many devices are configured at the same time. "
                                  + "Lower it if devices refuse SSH sessions."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }

                        StandardSpinBox {
                            id: canarySpin
                            objectName: "batchCanarySpin"
                            Layout.preferredWidth: 220
                            labelText: "Test wave size"
                            from: 0
                            to: 50
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "These first devices must finish before the rest start. 0 turns the test wave off."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }

                        StandardSpinBox {
                            id: failSpin
                            objectName: "batchFailPercentSpin"
                            Layout.preferredWidth: 220
                            labelText: "Stop above failure (%)"
                            from: 0
                            to: 100
                            stepSize: 5
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Once failures exceed this share, devices not started yet are skipped. 100 never stops."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                    }

                    InlineMessage {
                        Layout.fillWidth: true
                        message: root.resultMessage
                        severity: "success"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        StandardButton {
                            text: "Reload"
                            type: "Text"
                            onClicked: root.syncFields()
                        }
                        StandardButton {
                            objectName: "batchPolicySaveButton"
                            text: "Save"
                            type: "Primary"
                            enabled: root.backend !== null
                            onClicked: root.save()
                        }
                    }
                }
            }
        }
    }
}
