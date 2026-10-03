pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "complianceWorkspace"
    color: Theme.contentBackground

    readonly property var backend: typeof securityAuditController !== "undefined"
                                   && securityAuditController !== null
                                   ? securityAuditController : null

    property string statusFilter: "all"  // "all", "fail", "warning", "pass"
    property string copyFeedback: ""

    Timer {
        id: copyFeedbackTimer
        interval: 2000
        onTriggered: root.copyFeedback = ""
    }

    Component.onCompleted: {
        if (backend !== null && backend.totalDevices === 0 && !backend.isAuditing) {
            backend.runAuditAll()
        }
    }

    function getSeverityColor(sev) {
        switch (String(sev || "").toLowerCase()) {
        case "critical": return "#ef4444"
        case "high":     return "#f97316"
        case "medium":   return "#eab308"
        case "low":      return "#3b82f6"
        default:         return Theme.textSecondary
        }
    }

    function getStatusColor(status) {
        switch (String(status || "").toLowerCase()) {
        case "pass":    return Theme.alertSuccess
        case "fail":    return Theme.alertError
        case "warning": return Theme.alertWarning
        default:        return Theme.textDisabled
        }
    }

    function getGradeColor(grade) {
        switch (String(grade || "").toUpperCase()) {
        case "A": return "#10b981"
        case "B": return "#3b82f6"
        case "C": return "#f59e0b"
        case "D": return "#f97316"
        case "F": return "#ef4444"
        default:  return Theme.textSecondary
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── 1. Top Header Bar ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 38
                height: 38
                radius: 8
                color: Theme.isDarkMode ? "#1e2638" : "#eff6ff"
                border.color: Theme.accentColor
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: AppAssets.navigationAudit
                    sourceSize: Qt.size(20, 20)
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: LanguageState.isVietnamese
                          ? "Kiểm định Tuân thủ An ninh Cấu hình"
                          : "Security Compliance Audit"
                    color: Theme.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                    font.family: Theme.fontFamily
                }
                Text {
                    text: LanguageState.isVietnamese
                          ? "Đánh giá an toàn thiết bị Cisco IOS theo tiêu chuẩn CIS Benchmark & NSA Guidelines"
                          : "Audit Cisco IOS configurations against CIS Benchmark & NSA Security Guidelines"
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                }
            }

            Item { Layout.fillWidth: true }

            // Copy feedback toast
            Text {
                visible: root.copyFeedback !== ""
                text: root.copyFeedback
                color: Theme.alertSuccess
                font.pixelSize: 12
                font.bold: true
                font.family: Theme.fontFamily
            }

            // Export Report Button
            Button {
                id: exportBtn
                text: LanguageState.isVietnamese ? "Xuất báo cáo Markdown" : "Export Markdown"
                enabled: root.backend !== null && root.backend.totalDevices > 0 && !root.backend.isAuditing
                background: Rectangle {
                    implicitWidth: 160
                    implicitHeight: 34
                    color: exportBtn.hovered ? (Theme.isDarkMode ? "#2d333b" : "#e2e8f0") : Theme.contentPanelSurface
                    border.color: Theme.borderColor
                    radius: 6
                }
                contentItem: Text {
                    text: exportBtn.text
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.backend !== null) {
                        const defaultPath = "00_report/SECURITY_COMPLIANCE_REPORT.md"
                        const res = root.backend.exportMarkdownToFile(defaultPath)
                        root.copyFeedback = res.ok
                            ? (LanguageState.isVietnamese ? "Đã lưu vào 00_report/ !" : "Saved to 00_report/ !")
                            : res.message
                        copyFeedbackTimer.restart()
                    }
                }
            }

            // Run Audit Button
            Button {
                id: runBtn
                text: root.backend !== null && root.backend.isAuditing
                      ? (LanguageState.isVietnamese ? "Đang quét..." : "Auditing...")
                      : (LanguageState.isVietnamese ? "Quét lại toàn mạng" : "Run Full Audit")
                enabled: root.backend !== null && !root.backend.isAuditing
                background: Rectangle {
                    implicitWidth: 150
                    implicitHeight: 34
                    color: runBtn.enabled ? (runBtn.hovered ? Theme.accentEmphasis : Theme.accentColor) : Theme.contentPanelSurface
                    radius: 6
                }
                contentItem: Text {
                    text: runBtn.text
                    color: runBtn.enabled ? "#ffffff" : Theme.textDisabled
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.backend !== null) {
                        root.backend.runAuditAll()
                    }
                }
            }
        }

        // ── 2. Metric Overview Cards Row ────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Card 1: Điểm an ninh toàn mạng
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 26
                        color: Theme.isDarkMode ? "#222533" : "#f8fafc"
                        border.color: root.getGradeColor(root.backend ? root.backend.overallGrade : "--")
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: root.backend ? root.backend.overallGrade : "--"
                            color: root.getGradeColor(root.backend ? root.backend.overallGrade : "--")
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: LanguageState.isVietnamese ? "Chỉ số an ninh toàn mạng" : "Network Security Index"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                        RowLayout {
                            spacing: 6
                            Text {
                                text: root.backend ? Number(root.backend.averageScore).toFixed(1) : "0"
                                color: Theme.textPrimary
                                font.pixelSize: 22
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: "/ 100"
                                color: Theme.textSecondary
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignBaseline
                            }
                        }
                    }
                }
            }

            // Card 2: Phân bố tình trạng thiết bị
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: LanguageState.isVietnamese
                              ? ("Phân bố thiết bị (" + (root.backend ? root.backend.totalDevices : 0) + " thiết bị)")
                              : ("Device Distribution (" + (root.backend ? root.backend.totalDevices : 0) + " devices)")
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                    }

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            height: 24
                            implicitWidth: labelHealthy.implicitWidth + 16
                            radius: 12
                            color: Theme.isDarkMode ? "#132d22" : "#ecfdf5"
                            border.color: "#10b981"
                            border.width: 1

                            Text {
                                id: labelHealthy
                                anchors.centerIn: parent
                                text: "✓ " + (root.backend ? root.backend.healthyDevices : 0) + (LanguageState.isVietnamese ? " Tốt" : " Healthy")
                                color: "#10b981"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Rectangle {
                            height: 24
                            implicitWidth: labelWarning.implicitWidth + 16
                            radius: 12
                            color: Theme.isDarkMode ? "#332612" : "#fffbeb"
                            border.color: "#f59e0b"
                            border.width: 1

                            Text {
                                id: labelWarning
                                anchors.centerIn: parent
                                text: "! " + (root.backend ? root.backend.warningDevices : 0) + (LanguageState.isVietnamese ? " Cảnh báo" : " Warning")
                                color: "#f59e0b"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Rectangle {
                            height: 24
                            implicitWidth: labelCritical.implicitWidth + 16
                            radius: 12
                            color: Theme.isDarkMode ? "#351a1a" : "#fef2f2"
                            border.color: "#ef4444"
                            border.width: 1

                            Text {
                                id: labelCritical
                                anchors.centerIn: parent
                                text: "✕ " + (root.backend ? root.backend.criticalDevices : 0) + (LanguageState.isVietnamese ? " Nguy cấp" : " Critical")
                                color: "#ef4444"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // Card 3: Thống kê lỗ hổng an ninh
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: LanguageState.isVietnamese ? "Lỗ hổng an ninh phát hiện" : "Detected Vulnerabilities"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                    }

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            height: 24
                            implicitWidth: critVulnText.implicitWidth + 16
                            radius: 12
                            color: Theme.isDarkMode ? "#351a1a" : "#fef2f2"
                            border.color: "#ef4444"
                            border.width: 1

                            Text {
                                id: critVulnText
                                anchors.centerIn: parent
                                text: (root.backend ? root.backend.totalCriticalFails : 0) + " Critical"
                                color: "#ef4444"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Rectangle {
                            height: 24
                            implicitWidth: highVulnText.implicitWidth + 16
                            radius: 12
                            color: Theme.isDarkMode ? "#362215" : "#fff7ed"
                            border.color: "#f97316"
                            border.width: 1

                            Text {
                                id: highVulnText
                                anchors.centerIn: parent
                                text: (root.backend ? root.backend.totalHighFails : 0) + " High"
                                color: "#f97316"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Main Workspace Area (Split Sidebar & Detail) ──────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ── Left: Device List ───────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Text {
                        text: LanguageState.isVietnamese ? "DANH SÁCH THIẾT BỊ" : "DEVICE INVENTORY"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontFamily
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderColor
                    }

                    ListView {
                        id: deviceList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.backend ? root.backend.deviceReports : []
                        spacing: 4

                        delegate: Rectangle {
                            id: itemRect
                            required property var modelData
                            readonly property bool isSelected: root.backend !== null && root.backend.selectedHost === modelData.host

                            width: deviceList.width
                            height: 52
                            radius: 6
                            color: isSelected
                                   ? (Theme.isDarkMode ? "#252e3e" : "#e8effc")
                                   : (mouseArea.containsMouse ? (Theme.isDarkMode ? "#1b212d" : "#f1f5f9") : "transparent")
                            border.color: isSelected ? Theme.accentColor : (mouseArea.containsMouse ? Theme.borderColor : "transparent")
                            border.width: 1

                            Rectangle {
                                width: 3
                                height: parent.height - 14
                                radius: 1.5
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.accentColor
                                visible: itemRect.isSelected
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.backend !== null) {
                                        root.backend.selectDevice(itemRect.modelData.host)
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: itemRect.modelData.deviceName || itemRect.modelData.host
                                        color: itemRect.isSelected ? (Theme.isDarkMode ? "#79b8ff" : "#1a56db") : Theme.textPrimary
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: itemRect.modelData.host
                                            color: Theme.textSecondary
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: "•"
                                            color: Theme.textDisabled
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            text: itemRect.modelData.role === "rou" ? "Router" : "Switch"
                                            color: itemRect.isSelected
                                                   ? (Theme.isDarkMode ? "#93c5fd" : "#2563eb")
                                                   : Theme.textSecondary
                                            font.pixelSize: 10
                                            font.bold: itemRect.isSelected
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 42
                                    height: 22
                                    radius: 11
                                    color: Theme.isDarkMode ? "#1a1e28" : "#ffffff"
                                    border.color: root.getGradeColor(itemRect.modelData.grade)
                                    border.width: 1.5

                                    Text {
                                        anchors.centerIn: parent
                                        text: itemRect.modelData.score + "đ"
                                        color: root.getGradeColor(itemRect.modelData.grade)
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Right: Audit Details for Selected Device ────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Device Detail Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: {
                                    const rep = root.backend ? root.backend.selectedReport : null
                                    if (!rep || !rep.host) return LanguageState.isVietnamese ? "Chưa chọn thiết bị" : "No device selected"
                                    return (rep.deviceName || rep.host) + " (" + rep.host + ")"
                                }
                                color: Theme.textPrimary
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: {
                                    const rep = root.backend ? root.backend.selectedReport : null
                                    if (!rep || !rep.host) return ""
                                    return (LanguageState.isVietnamese ? "Điểm an ninh: " : "Security Score: ")
                                        + rep.score + "/100 (Hạng " + rep.grade + ") · "
                                        + rep.passedCount + " Đạt · "
                                        + rep.failedCount + " Vi phạm · "
                                        + rep.warningsCount + " Cảnh báo"
                                }
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Filter Chips (All, Fail, Warning, Pass)
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { "id": "all", "label": LanguageState.isVietnamese ? "Tất cả" : "All" },
                                    { "id": "fail", "label": LanguageState.isVietnamese ? "Vi phạm" : "Failed" },
                                    { "id": "warning", "label": LanguageState.isVietnamese ? "Cảnh báo" : "Warnings" },
                                    { "id": "pass", "label": LanguageState.isVietnamese ? "Đạt" : "Passed" }
                                ]
                                delegate: Button {
                                    id: filterBtn
                                    required property var modelData
                                    text: modelData.label
                                    background: Rectangle {
                                        implicitHeight: 28
                                        implicitWidth: filterBtnText.implicitWidth + 16
                                        radius: 14
                                        color: root.statusFilter === filterBtn.modelData.id
                                               ? Theme.accentColor
                                               : (filterBtn.hovered ? (Theme.isDarkMode ? "#21262d" : "#eef2f6") : "transparent")
                                        border.color: root.statusFilter === filterBtn.modelData.id
                                                      ? Theme.accentColor
                                                      : Theme.borderColor
                                    }
                                    contentItem: Text {
                                        id: filterBtnText
                                        text: filterBtn.text
                                        color: root.statusFilter === filterBtn.modelData.id ? "#ffffff" : Theme.textSecondary
                                        font.pixelSize: 11
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: root.statusFilter = filterBtn.modelData.id
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderColor
                    }

                    // Rule Results List
                    ListView {
                        id: rulesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8

                        model: {
                            const rep = root.backend ? root.backend.selectedReport : null
                            if (!rep || !rep.results) return []
                            const all = rep.results
                            if (root.statusFilter === "all") return all
                            return all.filter(function(r) { return r.status === root.statusFilter })
                        }

                        delegate: Rectangle {
                            id: ruleCard
                            required property var modelData
                            width: rulesList.width
                            implicitHeight: cardContent.implicitHeight + 20
                            radius: 6
                            color: Theme.contentBackground
                            border.color: {
                                const s = String(ruleCard.modelData.status || "").toLowerCase()
                                if (s === "fail") return Theme.isDarkMode ? "#4d1d1d" : "#fecaca"
                                if (s === "warning") return Theme.isDarkMode ? "#4d3a14" : "#fef08a"
                                if (s === "pass") return Theme.isDarkMode ? "#14402a" : "#bbf7d0"
                                return Theme.borderColor
                            }
                            border.width: 1

                            ColumnLayout {
                                id: cardContent
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                // Top row: Badge, ID, Title, Severity
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Status pill
                                    Rectangle {
                                        height: 20
                                        implicitWidth: statusText.implicitWidth + 12
                                        radius: 4
                                        color: root.getStatusColor(ruleCard.modelData.status)

                                        Text {
                                            id: statusText
                                            anchors.centerIn: parent
                                            text: {
                                                const s = String(ruleCard.modelData.status || "").toLowerCase()
                                                if (s === "pass") return LanguageState.isVietnamese ? "ĐẠT" : "PASS"
                                                if (s === "fail") return LanguageState.isVietnamese ? "VI PHẠM" : "FAIL"
                                                if (s === "warning") return LanguageState.isVietnamese ? "CẢNH BÁO" : "WARN"
                                                return "N/A"
                                            }
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    // Rule ID
                                    Text {
                                        text: "[" + ruleCard.modelData.ruleId + "]"
                                        color: Theme.textSecondary
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Cascadia Code, monospace"
                                    }

                                    // Title
                                    Text {
                                        Layout.fillWidth: true
                                        text: ruleCard.modelData.title
                                        color: Theme.textPrimary
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    // Severity tag
                                    Rectangle {
                                        height: 18
                                        implicitWidth: sevText.implicitWidth + 8
                                        radius: 3
                                        color: "transparent"
                                        border.color: root.getSeverityColor(ruleCard.modelData.severity)

                                        Text {
                                            id: sevText
                                            anchors.centerIn: parent
                                            text: String(ruleCard.modelData.severity || "").toUpperCase()
                                            color: root.getSeverityColor(ruleCard.modelData.severity)
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }

                                // Category & Details
                                Text {
                                    text: ruleCard.modelData.categoryTitle || ""
                                    color: Theme.accentColor
                                    font.pixelSize: 11
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: ruleCard.modelData.details || ""
                                    color: Theme.textPrimary
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                }

                                // Matched lines block (if fail/warn)
                                ColumnLayout {
                                    visible: ruleCard.modelData.matchedLines && ruleCard.modelData.matchedLines.length > 0
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: LanguageState.isVietnamese ? "Dòng cấu hình liên quan:" : "Matched configuration lines:"
                                        color: Theme.textSecondary
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: matchedText.implicitHeight + 10
                                        color: Theme.contentPanelSurface
                                        border.color: Theme.borderColor
                                        radius: 4

                                        Text {
                                            id: matchedText
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: (ruleCard.modelData.matchedLines || []).join("\n")
                                            color: Theme.alertError
                                            font.pixelSize: 11
                                            font.family: "Cascadia Code, monospace"
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }

                                // Remediation CLI Block (if fail/warn)
                                ColumnLayout {
                                    visible: ruleCard.modelData.remediation !== "" && ruleCard.modelData.status !== "pass"
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: LanguageState.isVietnamese ? "Câu lệnh Cisco IOS khắc phục khuyến nghị:" : "Recommended Cisco IOS remediation:"
                                            color: Theme.alertWarning
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        Item { Layout.fillWidth: true }
                                        Button {
                                            id: copyBtn
                                            text: LanguageState.isVietnamese ? "Sao chép lệnh" : "Copy CLI"
                                            background: Rectangle {
                                                implicitHeight: 22
                                                implicitWidth: 84
                                                radius: 3
                                                color: copyBtn.hovered ? (Theme.isDarkMode ? "#2d333b" : "#e2e8f0") : Theme.contentPanelSurface
                                                border.color: Theme.borderColor
                                            }
                                            contentItem: Text {
                                                text: copyBtn.text
                                                color: Theme.accentColor
                                                font.pixelSize: 10
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                if (root.backend !== null) {
                                                    root.backend.copyToClipboard(ruleCard.modelData.remediation)
                                                    root.copyFeedback = LanguageState.isVietnamese
                                                        ? "Đã sao chép câu lệnh khắc phục!"
                                                        : "Remediation CLI copied to clipboard!"
                                                    copyFeedbackTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: remText.implicitHeight + 12
                                        color: "#1e1e2e"
                                        radius: 4

                                        Text {
                                            id: remText
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: ruleCard.modelData.remediation
                                            color: "#a6e3a1"
                                            font.pixelSize: 11
                                            font.family: "Cascadia Code, monospace"
                                            wrapMode: Text.Wrap
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
}
