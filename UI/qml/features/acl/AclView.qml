pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: aclView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Standard"
    property string currentRulesTab: "Standard"
    property int viewPushRevision: 0
    property bool rulesLoaded: true
    property bool bindingsLoaded: false
    property string rulesHostIp: ""
    property string bindingsHostIp: ""
    readonly property bool isViewLoading: currentTab === "Bindings"
                                                  ? bindingsLoader.status === Loader.Loading
                                                  : rulesLoader.status === Loader.Loading

    function activeLoader() {
        return currentTab === "Bindings" ? bindingsLoader : rulesLoader
    }

    function hasUnsavedChanges(item) {
        if (!item)
            return false
        return item.hasPendingLocalChanges === true
                || item.hasPendingDeletes === true
                || item.dirty === true
                || (item.formMode !== undefined && Number(item.formMode) !== 0)
                || (item.isEditing && item.isEditing())
    }

    function reloadData(reason) {
        const loader = activeLoader()
        const item = loader ? loader.item : null
        if (!item || hasUnsavedChanges(item))
            return false
        if (item.reloadData)
            return item.reloadData(reason || "activation")
        if (currentTab === "Bindings" && item.reloadAll) {
            item.reloadAll()
            return true
        }
        if (currentTab !== "Bindings" && item.refreshSavedAcls) {
            item.refreshSavedAcls()
            return true
        }
        return false
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadAclData() {
        if (rulesLoader.item && rulesLoader.item.refreshSavedAcls)
            rulesLoader.item.refreshSavedAcls()
        if (bindingsLoader.item && bindingsLoader.item.reloadAll)
            bindingsLoader.item.reloadAll()
        viewPushRevision++
    }

    function refreshCollectedHost(updatedHost) {
        const host = String(updatedHost || "").trim()
        if (host === "") return
        Qt.callLater(function() {
            if (!aclView) return
            const loaders = [rulesLoader, bindingsLoader]
            for (let i = 0; i < loaders.length; ++i) {
                const item = loaders[i].item
                if (!item || String(item.currentHostIp || "").trim() !== host ||
                        item.hasPendingLocalChanges === true) continue
                if (item.reloadCollectedState) item.reloadCollectedState()
                else if (item.reloadAll) item.reloadAll()
            }
            aclView.viewPushRevision++
        })
    }

    Connections {
        target: typeof cli !== "undefined" ? cli : null
        function onRunningConfigFinished(host, ok, message) {
            if (ok) aclView.refreshCollectedHost(host)
        }
    }

    Connections {
        target: typeof dbManager !== "undefined" ? dbManager : null
        function onRunningConfigUpdated(host) {
            aclView.refreshCollectedHost(host)
        }
    }

    function activateTab(tabName) {
        currentTab = tabName
        syncHostToCurrentTab()
        ensureCurrentTabLoaded()
        activationReloadTimer.restart()
    }

    function ensureCurrentTabLoaded() {
        if (rulesLoader.status === Loader.Loading && currentTab === "Bindings")
            rulesLoaded = false
        if (bindingsLoader.status === Loader.Loading && currentTab !== "Bindings")
            bindingsLoaded = false

        if (currentTab === "Bindings")
            bindingsLoaded = true
        else
            rulesLoaded = true
    }

    function syncHostToCurrentTab() {
        if (currentTab === "Bindings")
            bindingsHostIp = currentHostIp
        else
            rulesHostIp = currentHostIp
    }

    onCurrentTabChanged: {
        if (currentTab !== "Bindings")
            currentRulesTab = currentTab
        syncHostToCurrentTab()
        ensureCurrentTabLoaded()
        activationReloadTimer.restart()
    }
    onCurrentHostIpChanged: syncHostToCurrentTab()
    Component.onCompleted: syncHostToCurrentTab()

    Timer {
        id: activationReloadTimer
        interval: 0
        repeat: false
        onTriggered: aclView.reloadData("subfeature-activated")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        AclSubBar {
            Layout.fillWidth: true
            activeTab:        aclView.currentTab
            onTabClicked:     (tabName) => aclView.activateTab(tabName)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: Theme.contentSurface

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.borderColor
            }

            WorkspaceHeader {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                title: "Access Control Lists"
                subtitle: String(aclView.currentHostIp || "").trim() === ""
                          ? "No device selected"
                          : aclView.currentHostIp

                ViewPushButton {
                    type: "Primary"
                    controllerName: "acl"
                    moduleName: "all"
                    hostIp: aclView.currentHostIp
                    ownerForm: aclView
                    refreshKey: aclView.viewPushRevision
                    onPushCompleted: function(ok, message) {
                        if (ok)
                            aclView.reloadAclData()
                    }
                }
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            wrapText: true
            message: "IP ACL rules and the final deny generate logs. Configure the Syslog destination separately for this device with trap severity 6 or 7. MAC ACL and reflexive reflect/evaluate rules do not support per-match logging on IOS."
        }

        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            Loader {
                id: rulesLoader
                objectName: "aclRulesLoader"
                anchors.fill: parent
                active: aclView.rulesLoaded
                asynchronous: true
                visible: aclView.currentTab !== "Bindings"
                sourceComponent: Component {
                    AclForm {
                        currentHostIp: aclView.rulesHostIp
                        currentAclType: aclView.currentRulesTab
                    }
                }
            }

            Loader {
                id: bindingsLoader
                objectName: "aclBindingsLoader"
                anchors.fill: parent
                active: aclView.bindingsLoaded
                asynchronous: true
                visible: aclView.currentTab === "Bindings"
                sourceComponent: Component {
                    AclBindingsTab { currentHostIp: aclView.bindingsHostIp }
                }
            }
        }
    }
}
