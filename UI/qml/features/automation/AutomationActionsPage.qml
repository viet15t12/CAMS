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
    property var actions: []

    function reloadActions() {
        actions = backend !== null ? backend.getActions() : []
    }

    Component.onCompleted: reloadActions()

    Connections {
        target: root.backend
        function onActionsChanged() { root.reloadActions() }
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
                    text: "Action History"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Inspect simulated actions produced by scheduled rules. No request shown here was sent to a device."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }
            }
            StandardButton {
                text: "Refresh"
                icon.source: AppAssets.actionRefresh
                onClicked: root.reloadActions()
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            message: "Current mode: dry-run · network mutation disabled"
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
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.spacing8

                    Text {
                        Layout.fillWidth: true
                        visible: root.actions.length === 0
                        text: "No action has been simulated yet."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Repeater {
                        model: root.actions
                        delegate: Rectangle {
                            id: actionCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: actionLayout.implicitHeight + 20
                            color: Theme.contentBackground
                            radius: Theme.radiusSmall
                            border.width: Theme.borderWidth
                            border.color: Theme.borderColor

                            ColumnLayout {
                                id: actionLayout
                                anchors.fill: parent
                                anchors.margins: Theme.spacing8
                                spacing: Theme.spacing4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: "%1 · %2"
                                              .arg(actionCard.modelData.rule_id)
                                              .arg(actionCard.modelData.action_type)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    StandardBadge {
                                        text: String(actionCard.modelData.status || "simulated").toUpperCase()
                                        badgeColor: Theme.notificationInfoAccent
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "%1 · %2 · %3"
                                          .arg(actionCard.modelData.created_at)
                                          .arg(actionCard.modelData.device_host)
                                          .arg(actionCard.modelData.subject_key)
                                    color: Theme.textSecondary
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: JSON.stringify(actionCard.modelData.request_redacted || {})
                                    color: Theme.textDisabled
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
