pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "telegramAlertSettings"
    color: Theme.contentBackground

    readonly property var backend: typeof telegramAlertManager !== "undefined"
                                   && telegramAlertManager !== null
                                   ? telegramAlertManager : null
    property bool loading: false
    property bool alertEnabled: false
    property var selectedLevels: [0, 1, 2]
    property bool hasSavedToken: false
    property bool advancedExpanded: false
    property string savedSnapshot: ""
    property var validationErrors: ({})
    readonly property bool testSending: backend !== null && backend.testSending
    property string feedbackMessage: ""
    property string feedbackSeverity: "info"

    readonly property var levelDefinitions: [
        { "level": 0, "name": "Emergency", "color": "#7f1d1d" },
        { "level": 1, "name": "Alert", "color": "#b91c1c" },
        { "level": 2, "name": "Critical", "color": "#c2410c" },
        { "level": 3, "name": "Error", "color": "#d97706" },
        { "level": 4, "name": "Warning", "color": "#a16207" },
        { "level": 5, "name": "Notice", "color": "#2563eb" },
        { "level": 6, "name": "Info", "color": "#0f766e" },
        { "level": 7, "name": "Debug", "color": "#4b5563" }
    ]

    readonly property bool noisyLevelsSelected: selectedLevels.indexOf(5) !== -1
                                                || selectedLevels.indexOf(6) !== -1
                                                || selectedLevels.indexOf(7) !== -1
    readonly property bool dirty: !loading && savedSnapshot !== ""
                                  && currentSnapshot() !== savedSnapshot

    function tr(en, vi) {
        return LanguageState.isVietnamese ? vi : en
    }

    function levelDescription(level) {
        const en = [
            "System is unusable", "Immediate action required", "Critical condition",
            "Error condition", "Warning condition", "Normal but significant event",
            "Informational message", "Debug message"
        ]
        const vi = [
            "Hệ thống không thể sử dụng", "Cần hành động ngay", "Tình trạng nghiêm trọng",
            "Lỗi", "Cảnh báo", "Sự kiện đáng chú ý", "Thông tin", "Gỡ lỗi"
        ]
        return LanguageState.isVietnamese ? vi[level] : en[level]
    }

    function payload() {
        return {
            "enabled": alertEnabled,
            "bot_token": botToken.text.replace(/\s/g, ""),
            "chat_id": chatId.text.trim(),
            "levels": selectedLevels.slice(0),
            "cooldown_seconds": cooldownSeconds.value,
            "batch_seconds": batchSeconds.value
        }
    }

    function currentSnapshot() {
        const data = payload()
        data.token_changed = botToken.text !== ""
        data.bot_token = ""
        return JSON.stringify(data)
    }

    function loadConfiguration() {
        if (backend === null)
            return
        loading = true
        const config = backend.loadConfiguration()
        alertEnabled = Boolean(config.enabled)
        selectedLevels = (config.levels || [0, 1, 2]).slice(0)
        botToken.text = ""
        hasSavedToken = Boolean(config.has_token)
        chatId.text = String(config.chat_id || "")
        cooldownSeconds.value = Number(config.cooldown_seconds ?? 300)
        batchSeconds.value = Number(config.batch_seconds ?? 10)
        validationErrors = ({})
        feedbackMessage = testSending
                ? tr("Sending test Telegram message...", "Đang gửi tin nhắn thử...")
                : ""
        feedbackSeverity = "info"
        savedSnapshot = currentSnapshot()
        loading = false
    }

    function setLevel(level, checked) {
        const next = selectedLevels.slice(0)
        const index = next.indexOf(level)
        if (checked && index === -1)
            next.push(level)
        else if (!checked && index !== -1)
            next.splice(index, 1)
        next.sort(function(a, b) { return a - b })
        selectedLevels = next
    }

    function addLevels(levels) {
        const next = selectedLevels.slice(0)
        for (let i = 0; i < levels.length; i++) {
            if (next.indexOf(levels[i]) === -1)
                next.push(levels[i])
        }
        next.sort(function(a, b) { return a - b })
        selectedLevels = next
    }

    function fieldError(name) {
        return validationErrors[name] ? String(validationErrors[name]) : ""
    }

    function applyResult(result) {
        validationErrors = result && result.errors ? result.errors : ({})
        feedbackMessage = String(result && result.message ? result.message : "")
        feedbackSeverity = result && result.ok ? "success" : "error"
        return Boolean(result && result.ok)
    }

    function saveConfiguration() {
        if (backend === null)
            return
        const result = backend.saveConfiguration(payload(), LanguageState.language)
        if (applyResult(result)) {
            const savedMessage = feedbackMessage
            loadConfiguration()
            feedbackMessage = savedMessage
            feedbackSeverity = "success"
        }
    }

    function sendTest() {
        if (backend === null || testSending)
            return
        const result = backend.sendTestTelegram(payload(), LanguageState.language)
        if (applyResult(result))
            feedbackSeverity = "info"
    }

    Connections {
        target: root.backend
        enabled: root.backend !== null
        function onTestTelegramFinished(ok, message) {
            root.feedbackMessage = String(message || "")
            root.feedbackSeverity = ok ? "success" : "error"
        }
        function onAlertError(message) {
            if (!root.testSending) {
                root.feedbackMessage = String(message || "")
                root.feedbackSeverity = "error"
            }
        }
    }

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
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                spacing: Theme.spacing4

                Text {
                    Layout.fillWidth: true
                    text: root.tr("Telegram Alerts", "Cảnh báo qua Telegram")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.tr(
                        "Send selected Cisco Syslog levels through a Telegram bot without blocking the listener.",
                        "Gửi các mức Cisco Syslog đã chọn qua Telegram bot mà không làm chậm listener."
                    )
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            FormSection {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                title: root.tr("Telegram delivery", "Gửi cảnh báo qua Telegram")

                StandardToggleButton {
                    objectName: "telegramAlertsEnabled"
                    Layout.fillWidth: true
                    text: root.tr(
                        "Send Syslog alerts to Telegram",
                        "Gửi cảnh báo Syslog tới Telegram"
                    )
                    description: root.tr(
                        "Eligible logs are queued and delivered by the configured bot.",
                        "Log phù hợp được đưa vào hàng đợi và gửi bằng bot đã cấu hình."
                    )
                    checked: root.alertEnabled
                    onToggled: root.alertEnabled = checked
                }
            }

            FormSection {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                title: root.tr("1. Alert levels", "1. Mức log cần cảnh báo")
                enabled: root.alertEnabled
                opacity: enabled ? 1 : 0.55

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacing8

                    StandardButton {
                        text: root.tr("Critical 0–2", "Nghiêm trọng 0–2")
                        type: "Secondary"
                        onClicked: root.addLevels([0, 1, 2])
                    }
                    StandardButton {
                        text: root.tr("Error / Warning 3–4", "Lỗi / Cảnh báo 3–4")
                        type: "Secondary"
                        onClicked: root.addLevels([3, 4])
                    }
                    StandardButton {
                        text: root.tr("Information 5–7", "Thông tin 5–7")
                        type: "Secondary"
                        onClicked: root.addLevels([5, 6, 7])
                    }
                    StandardButton {
                        text: root.tr("Select all", "Chọn tất cả")
                        type: "Secondary"
                        onClicked: root.selectedLevels = [0, 1, 2, 3, 4, 5, 6, 7]
                    }
                    StandardButton {
                        text: root.tr("Clear", "Bỏ chọn")
                        type: "Text"
                        onClicked: root.selectedLevels = []
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 720 ? 2 : 1
                    columnSpacing: Theme.spacing16
                    rowSpacing: Theme.spacing8

                    Repeater {
                        model: root.levelDefinitions

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.spacing8

                            Rectangle {
                                Layout.preferredWidth: 10
                                Layout.preferredHeight: 10
                                radius: 5
                                color: parent.modelData.color
                            }

                            StandardCheckBox {
                                Layout.fillWidth: true
                                text: parent.modelData.level + "  " + parent.modelData.name
                                      + " — " + root.levelDescription(parent.modelData.level)
                                checked: root.selectedLevels.indexOf(parent.modelData.level) !== -1
                                onToggled: root.setLevel(parent.modelData.level, checked)
                            }
                        }
                    }
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "warning"
                    wrapText: true
                    message: root.noisyLevelsSelected ? root.tr(
                        "Levels 5–7 can create many Telegram messages. Consider increasing the cooldown.",
                        "Level 5–7 có thể tạo nhiều tin nhắn Telegram. Nên tăng thời gian chống spam."
                    ) : ""
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "error"
                    message: root.fieldError("levels")
                }
            }

            FormSection {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                title: root.tr("2. Telegram bot", "2. Telegram bot")
                enabled: root.alertEnabled
                opacity: enabled ? 1 : 0.55

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: Theme.spacing12
                    rowSpacing: Theme.spacing8

                    StandardPasswordField {
                        id: botToken
                        objectName: "telegramAlertsBotToken"
                        Layout.fillWidth: true
                        labelText: "Bot Token"
                        placeholderText: root.hasSavedToken
                                         ? "••••••••"
                                         : "123456789:AA..."
                        onTextEdited: function(value) {
                            const normalized = value.replace(/\s/g, "")
                            if (text !== normalized)
                                text = normalized
                        }
                    }

                    StandardTextField {
                        id: chatId
                        objectName: "telegramAlertsChatId"
                        Layout.fillWidth: true
                        labelText: "Chat ID"
                        placeholderText: "-1001234567890"
                    }
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "info"
                    wrapText: true
                    message: root.tr(
                        "Create a bot with @BotFather, send /start to the bot, then enter the numeric Chat ID. A public channel username such as @network_alerts is also supported. Leave Bot Token blank after reopening to keep the saved token.",
                        "Tạo bot bằng @BotFather, gửi /start cho bot rồi nhập Chat ID dạng số. Cũng hỗ trợ username kênh công khai như @network_alerts. Khi mở lại, để trống Bot Token để giữ token đã lưu."
                    )
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "error"
                    wrapText: true
                    message: root.fieldError("bot_token") || root.fieldError("chat_id")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                implicitHeight: advancedLayout.implicitHeight + Theme.spacing16 * 2
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                border.width: Theme.borderWidth
                radius: Theme.radiusMedium
                enabled: root.alertEnabled
                opacity: enabled ? 1 : 0.55

                ColumnLayout {
                    id: advancedLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacing16
                    spacing: Theme.spacing12

                    StandardButton {
                        Layout.alignment: Qt.AlignLeft
                        type: "TextIcon"
                        text: root.tr("3. Anti-spam (advanced)", "3. Chống spam (nâng cao)")
                        icon.source: root.advancedExpanded
                                     ? AppAssets.navigationChevronUp
                                     : AppAssets.navigationChevronDown
                        onClicked: root.advancedExpanded = !root.advancedExpanded
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.advancedExpanded
                        columns: width >= 620 ? 2 : 1
                        columnSpacing: Theme.spacing12
                        rowSpacing: Theme.spacing8

                        StandardSpinBox {
                            id: cooldownSeconds
                            Layout.fillWidth: true
                            labelText: root.tr(
                                "Duplicate cooldown (seconds)",
                                "Không gửi lại log trùng (giây)"
                            )
                            from: 0
                            to: 86400
                            value: 300
                            editable: true
                        }

                        StandardSpinBox {
                            id: batchSeconds
                            Layout.fillWidth: true
                            labelText: root.tr(
                                "Batch window (seconds)",
                                "Gom cảnh báo trong (giây)"
                            )
                            from: 0
                            to: 86400
                            value: 10
                            editable: true
                        }

                        Text {
                            Layout.columnSpan: parent.columns
                            Layout.fillWidth: true
                            text: root.tr(
                                "A value of 0 disables that anti-spam function. Telegram messages are limited to 4096 characters, so oversized batches are summarized.",
                                "Giá trị 0 sẽ tắt tính năng tương ứng. Tin nhắn Telegram giới hạn 4096 ký tự nên đợt quá dài sẽ được tóm tắt."
                            )
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            InlineMessage {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                severity: root.feedbackSeverity
                busy: root.testSending
                wrapText: true
                message: root.feedbackMessage
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                spacing: Theme.spacing8

                StandardButton {
                    objectName: "telegramAlertsTestButton"
                    text: root.testSending
                          ? root.tr("Sending...", "Đang gửi...")
                          : root.tr("Send test message", "Gửi tin nhắn thử")
                    type: "Secondary"
                    icon.source: AppAssets.actionPush
                    enabled: root.alertEnabled && !root.testSending && root.backend !== null
                    onClicked: root.sendTest()
                }

                Item { Layout.fillWidth: true }

                StandardButton {
                    text: root.tr("Cancel", "Hủy")
                    type: "Text"
                    enabled: root.dirty && !root.testSending
                    onClicked: root.loadConfiguration()
                }

                StandardButton {
                    objectName: "telegramAlertsSaveButton"
                    text: root.tr("Save settings", "Lưu cấu hình")
                    type: "Primary"
                    icon.source: AppAssets.actionSave
                    enabled: root.dirty && !root.testSending && root.backend !== null
                    onClicked: root.saveConfiguration()
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.spacing24 }
        }
    }

    onVisibleChanged: if (visible) loadConfiguration()
    Component.onCompleted: loadConfiguration()
}
