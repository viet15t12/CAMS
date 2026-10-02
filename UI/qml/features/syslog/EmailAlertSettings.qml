pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "emailAlertSettings"
    color: Theme.contentBackground

    readonly property var backend: typeof emailAlertManager !== "undefined"
                                   && emailAlertManager !== null
                                   ? emailAlertManager : null
    property bool loading: false
    property bool alertEnabled: false
    property var selectedLevels: [0, 1, 2]
    property bool hasSavedPassword: false
    property bool advancedExpanded: false
    property int recipientRevision: 0
    property string savedSnapshot: ""
    property var validationErrors: ({})
    property bool testSending: false
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

    function recipientsPayload() {
        const watchRevision = recipientRevision
        const values = []
        for (let i = 0; i < recipientModel.count; i++)
            values.push(String(recipientModel.get(i).value || "").trim())
        return values
    }

    function payload() {
        return {
            "enabled": alertEnabled,
            "smtp_host": smtpHost.text.trim(),
            "smtp_port": smtpPort.value,
            "sender_email": senderEmail.text.trim(),
            "sender_app_password": appPassword.text.replace(/\s/g, ""),
            "recipients": recipientsPayload(),
            "levels": selectedLevels.slice(0),
            "cooldown_seconds": cooldownSeconds.value,
            "batch_seconds": batchSeconds.value
        }
    }

    function currentSnapshot() {
        const data = payload()
        data.password_changed = appPassword.text !== ""
        data.sender_app_password = ""
        return JSON.stringify(data)
    }

    function loadConfiguration() {
        if (backend === null)
            return
        loading = true
        const config = backend.loadConfiguration()
        alertEnabled = Boolean(config.enabled)
        selectedLevels = (config.levels || [0, 1, 2]).slice(0)
        smtpHost.text = String(config.smtp_host || "smtp.gmail.com")
        smtpPort.value = Number(config.smtp_port || 465)
        senderEmail.text = String(config.sender_email || "")
        appPassword.text = ""
        hasSavedPassword = Boolean(config.has_password)
        recipientModel.clear()
        const values = config.recipients && config.recipients.length > 0
                       ? config.recipients : [""]
        for (let i = 0; i < values.length; i++)
            recipientModel.append({ "value": String(values[i] || "") })
        cooldownSeconds.value = Number(config.cooldown_seconds ?? 300)
        batchSeconds.value = Number(config.batch_seconds ?? 10)
        recipientRevision++
        validationErrors = ({})
        feedbackMessage = ""
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

    function updateRecipient(index, value) {
        const parts = String(value || "").split(/[,;\n]+/)
        if (parts.length > 1) {
            const available = Math.max(1, 20 - recipientModel.count + 1)
            const normalized = parts.map(function(item) { return item.trim() })
                                    .filter(function(item) { return item !== "" })
                                    .slice(0, available)
            if (normalized.length > 0) {
                recipientModel.setProperty(index, "value", normalized[0])
                for (let i = 1; i < normalized.length; i++)
                    recipientModel.insert(index + i, { "value": normalized[i] })
            }
        } else {
            recipientModel.setProperty(index, "value", value)
        }
        recipientRevision++
    }

    function removeRecipient(index) {
        if (recipientModel.count <= 1)
            return
        recipientModel.remove(index)
        recipientRevision++
    }

    function recipientIssue(index) {
        const backendIssue = validationErrors["recipients." + index]
        if (backendIssue)
            return String(backendIssue)
        const value = String(recipientModel.get(index).value || "").trim()
        if (value === "")
            return ""
        const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
        if (!valid)
            return tr("Email address is invalid.", "Email không hợp lệ.")
        for (let i = 0; i < recipientModel.count; i++) {
            if (i !== index && value.toLowerCase()
                    === String(recipientModel.get(i).value || "").trim().toLowerCase())
                return tr("This email is already in the list.", "Email này đã có trong danh sách.")
        }
        return ""
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
        const result = backend.sendTestEmail(payload(), LanguageState.language)
        if (applyResult(result)) {
            testSending = true
            feedbackSeverity = "info"
        }
    }

    ListModel { id: recipientModel }

    Connections {
        target: root.backend
        enabled: root.backend !== null
        function onTestEmailFinished(ok, message) {
            root.testSending = false
            root.feedbackMessage = String(message || "")
            root.feedbackSeverity = ok ? "success" : "error"
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
                    text: root.tr("Email Alerts", "Cảnh báo qua email")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.tr(
                        "Send selected Cisco Syslog levels by email without blocking the listener.",
                        "Gửi các mức Cisco Syslog đã chọn qua email mà không làm chậm listener."
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
                title: root.tr("Email delivery", "Gửi cảnh báo log qua email")

                StandardToggleButton {
                    objectName: "emailAlertsEnabled"
                    Layout.fillWidth: true
                    text: root.tr("Send Syslog alerts by email", "Gửi cảnh báo log qua email")
                    description: root.tr(
                        "When enabled, logs at the selected levels are queued for email delivery.",
                        "Khi bật, log thuộc các level đã chọn sẽ được đưa vào hàng đợi gửi email."
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing8

                    Text {
                        text: root.tr("Quick select:", "Chọn nhanh:")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

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
                        "Levels 5–7 can generate many logs and emails. Consider increasing the cooldown.",
                        "Level 5–7 phát sinh rất nhiều log và email. Nên tăng thời gian chống spam."
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
                title: root.tr("2. Sender account (SMTP)", "2. Tài khoản gửi (SMTP)")
                enabled: root.alertEnabled
                opacity: enabled ? 1 : 0.55

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: Theme.spacing12
                    rowSpacing: Theme.spacing8

                    StandardTextField {
                        id: smtpHost
                        Layout.fillWidth: true
                        labelText: root.tr("SMTP server", "Máy chủ SMTP")
                        placeholderText: "smtp.gmail.com"
                    }

                    StandardSpinBox {
                        id: smtpPort
                        Layout.fillWidth: true
                        labelText: root.tr("Port", "Cổng")
                        from: 1
                        to: 65535
                        value: 465
                        editable: true
                    }

                    StandardTextField {
                        id: senderEmail
                        Layout.fillWidth: true
                        labelText: root.tr("Sender email", "Email gửi")
                        placeholderText: "cams.syslog.alert@gmail.com"
                    }

                    StandardPasswordField {
                        id: appPassword
                        Layout.fillWidth: true
                        labelText: "App Password"
                        placeholderText: root.hasSavedPassword
                                         ? "••••••••"
                                         : root.tr("16-character App Password", "App Password 16 ký tự")
                        onTextEdited: function(value) {
                            const normalized = value.replace(/\s/g, "")
                            if (text !== normalized)
                                text = normalized
                        }
                    }
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "info"
                    wrapText: true
                    message: root.tr(
                        "For Gmail, use a 16-character App Password, not the normal account password. Leave this field blank after reopening to keep the saved password.",
                        "Với Gmail, dùng App Password 16 ký tự, không dùng mật khẩu thường. Khi mở lại, để trống ô này để giữ mật khẩu đã lưu."
                    )

                    StandardButton {
                        text: root.tr("Create App Password", "Tạo App Password")
                        type: "Text"
                        onClicked: Qt.openUrlExternally("https://myaccount.google.com/apppasswords")
                    }
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "error"
                    wrapText: true
                    message: root.fieldError("smtp_host") || root.fieldError("smtp_port")
                             || root.fieldError("sender_email")
                             || root.fieldError("sender_app_password")
                }
            }

            FormSection {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing24
                Layout.rightMargin: Theme.spacing24
                title: root.tr("3. Recipients", "3. Người nhận")
                enabled: root.alertEnabled
                opacity: enabled ? 1 : 0.55

                Repeater {
                    model: recipientModel

                    delegate: ColumnLayout {
                        required property int index
                        required property string value
                        Layout.fillWidth: true
                        spacing: Theme.spacing4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing8

                            StandardTextField {
                                Layout.fillWidth: true
                                labelText: root.tr("Recipient %1", "Người nhận %1").arg(parent.parent.index + 1)
                                placeholderText: "admin@example.com"
                                text: parent.parent.value
                                onTextEdited: function(value) {
                                    root.updateRecipient(parent.parent.index, value)
                                }
                            }

                            StandardButton {
                                Layout.alignment: Qt.AlignBottom
                                type: "Icon"
                                icon.source: AppAssets.actionClose
                                tooltip: root.tr("Remove recipient", "Xóa người nhận")
                                enabled: recipientModel.count > 1
                                onClicked: root.removeRecipient(parent.parent.index)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.recipientIssue(parent.index)
                            color: Theme.alertError
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                StandardButton {
                    text: root.tr("+ Add recipient", "+ Thêm email nhận")
                    type: "Text"
                    enabled: recipientModel.count < 20
                    onClicked: {
                        recipientModel.append({ "value": "" })
                        root.recipientRevision++
                    }
                }

                InlineMessage {
                    Layout.fillWidth: true
                    severity: "error"
                    message: root.fieldError("recipients")
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
                        text: root.tr("4. Anti-spam (advanced)", "4. Chống spam (nâng cao)")
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
                            labelText: root.tr("Duplicate cooldown (seconds)", "Không gửi lại log trùng (giây)")
                            from: 0
                            to: 86400
                            value: 300
                            editable: true
                        }

                        StandardSpinBox {
                            id: batchSeconds
                            Layout.fillWidth: true
                            labelText: root.tr("Batch window (seconds)", "Gom cảnh báo trong (giây)")
                            from: 0
                            to: 86400
                            value: 10
                            editable: true
                        }

                        Text {
                            Layout.columnSpan: parent.columns
                            Layout.fillWidth: true
                            text: root.tr(
                                "A value of 0 disables that anti-spam function. Duplicates use the same device and Cisco code.",
                                "Giá trị 0 sẽ tắt tính năng tương ứng. Log trùng được xác định theo cùng thiết bị và mã Cisco."
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
                    objectName: "emailAlertsTestButton"
                    text: root.testSending
                          ? root.tr("Sending...", "Đang gửi...")
                          : root.tr("Send test email", "Gửi email thử")
                    type: "Secondary"
                    icon.source: AppAssets.fileTypeEmail
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
                    objectName: "emailAlertsSaveButton"
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
