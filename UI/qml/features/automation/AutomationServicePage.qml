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

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacing16

            Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.spacing8 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: Theme.spacing4

                Text {
                    text: "Automation Service"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Manage validated version 1 typed actions and version 2 CLI sequences executed through the active CAMS SSH session."
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
                Layout.preferredHeight: serviceLayout.implicitHeight + 32
                color: Theme.searchBackground2
                radius: Theme.borderRadius
                border.width: Theme.borderWidth
                border.color: Theme.borderColor

                ColumnLayout {
                    id: serviceLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacing16
                    spacing: Theme.spacing12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing4
                            Text {
                                text: root.backend !== null
                                      ? root.backend.serviceName
                                      : "Automation unavailable"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.backend !== null
                                      ? root.backend.statusMessage
                                      : "The automation backend is unavailable."
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }
                        }

                        StandardBadge {
                            text: root.backend !== null
                                  ? String(root.backend.state).toUpperCase()
                                  : "UNAVAILABLE"
                            badgeColor: root.backend !== null && root.backend.running
                                        ? Theme.alertSuccess : Theme.textDisabled
                        }

                        StandardButton {
                            objectName: "automationServiceToggleButton"
                            text: root.backend !== null && root.backend.running
                                  ? "Stop Engine" : "Start Engine"
                            icon.source: root.backend !== null && root.backend.running
                                         ? AppAssets.actionMonitorStop
                                         : AppAssets.actionMonitorStart
                            enabled: root.backend !== null && !root.backend.busy
                            onClicked: {
                                if (root.backend.running)
                                    root.backend.stop()
                                else
                                    root.backend.start()
                            }
                        }
                    }

                    InlineMessage {
                        Layout.fillWidth: true
                        message: root.backend !== null
                                 && root.backend.ruleErrors.length > 0
                                 ? "%1 invalid rule file(s) block evaluation."
                                      .arg(root.backend.ruleErrors.length)
                                 : "Dry-run is enforced by Python and Go. No device configuration is changed."
                        severity: root.backend !== null
                                  && root.backend.ruleErrors.length > 0
                                  ? "warning" : "info"
                        busy: root.backend !== null && root.backend.busy
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.backend !== null
                              ? "Command: %1 · Rules: %2"
                                  .arg(root.backend.serviceCommand)
                                  .arg(root.backend.rulesDirectory)
                              : ""
                        color: Theme.textDisabled
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideMiddle
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: Theme.spacing12

                Repeater {
                    model: [
                        { "label": "Valid rules", "value": root.backend !== null ? root.backend.ruleCount : 0 },
                        { "label": "Recorded actions", "value": root.backend !== null ? root.backend.actionCount : 0 },
                        { "label": "Rule errors", "value": root.backend !== null ? root.backend.ruleErrors.length : 0 }
                    ]

                    delegate: Rectangle {
                        id: metricCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        color: Theme.searchBackground2
                        radius: Theme.borderRadius
                        border.width: Theme.borderWidth
                        border.color: Theme.borderColor

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacing4
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: String(metricCard.modelData.value)
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: metricCard.modelData.label
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: errorsLayout.implicitHeight + 24
                visible: root.backend !== null && root.backend.ruleErrors.length > 0
                color: Theme.searchBackground2
                radius: Theme.borderRadius
                border.width: Theme.borderWidth
                border.color: Theme.alertWarning

                ColumnLayout {
                    id: errorsLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacing12
                    spacing: Theme.spacing8
                    Text {
                        text: "Rule validation errors"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }
                    Repeater {
                        model: root.backend !== null ? root.backend.ruleErrors : []
                        delegate: Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: "%1 — %2".arg(modelData.file).arg(modelData.error)
                            color: Theme.alertWarning
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.spacing8 }
        }
    }
}
