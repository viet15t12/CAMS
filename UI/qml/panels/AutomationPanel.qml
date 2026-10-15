pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Item {
    id: root
    objectName: "automationPanel"

    signal pageSelected(string key)

    property int selectedIndex: 0
    readonly property var pages: [
        { "key": "service", "title": "Service", "desc": "Engine status, lifecycle, and validation errors" },
        { "key": "rules", "title": "Rule Files", "desc": "Import, enable, disable, edit, and delete rules" },
        { "key": "editor", "title": "Rule Editor", "desc": "Write and validate declarative JSON rules" },
        { "key": "actions", "title": "Action History", "desc": "Inspect recent automatic and dry-run actions" }
    ]
    readonly property string selectedKey:
        selectedIndex >= 0 && selectedIndex < pages.length
        ? pages[selectedIndex].key : "service"
    readonly property int renderedCardCount: pageRepeater.count

    function selectPage(key) {
        const normalized = String(key || "")
        for (let i = 0; i < pages.length; ++i) {
            if (pages[i].key === normalized) {
                if (selectedIndex === i)
                    pageSelected(normalized)
                else
                    selectedIndex = i
                return true
            }
        }
        return false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelSideBarBackground
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.panelSideBarBackground

            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                verticalAlignment: Text.AlignVCenter
                text: "AUTOMATION"
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.capitalization: Font.AllUppercase
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.panelSideBarBorderColor
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 8

                Item { Layout.fillWidth: true; Layout.preferredHeight: 0 }

                Repeater {
                    id: pageRepeater
                    model: root.pages

                    delegate: Rectangle {
                        id: pageCard
                        required property int index
                        required property var modelData

                        objectName: "automationPageCard" + index
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        implicitHeight: Math.max(72, pageContent.implicitHeight + 24)
                        radius: Theme.borderRadius
                        color: root.selectedIndex === index
                               ? Theme.panelSideBarItemSelected
                               : (pageHover.hovered
                                  ? Theme.panelSideBarItemHover
                                  : Theme.panelSideBarSearchBackground2)
                        border.width: Theme.borderWidth
                        border.color: Theme.panelSideBarBorderColor

                        ColumnLayout {
                            id: pageContent
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Text {
                                text: pageCard.modelData.title
                                color: Theme.panelSideBarTextPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: pageCard.modelData.desc
                                color: Theme.panelSideBarTextSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }
                        }

                        HoverHandler { id: pageHover }
                        TapHandler { onTapped: root.selectedIndex = pageCard.index }
                    }
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
            }
        }
    }

    onSelectedKeyChanged: pageSelected(selectedKey)
}
