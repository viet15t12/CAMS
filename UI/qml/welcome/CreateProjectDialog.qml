pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: root

    property string defaultProjectDirectory: ""
    property var locationIsDefault: null

    signal browseLocationRequested(string currentLocation)
    signal createRequested(string projectName, string projectLocation,
                           string password, bool setAsDefault)

    title: "Create New Project"
    subtitle: "Start a CAMS workspace"
    preferredWidth: 600
    implicitHeight: protectProjectCheck.checked ? 625 : 485

    function normalizedLocation(value) {
        let path = String(value || "").trim().replace(/\\/g, "/")
        while (path.length > 1 && path.endsWith("/"))
            path = path.slice(0, -1)
        return Qt.platform.os === "windows" ? path.toLowerCase() : path
    }

    function setProjectLocation(location) {
        if (String(location || "").trim().length > 0)
            projectLocationField.text = location
    }

    onOpened: {
        projectLocationField.text = root.defaultProjectDirectory
        projectNameField.forceActiveFocus()
    }
    onClosed: {
        projectNameField.clear()
        projectLocationField.clear()
        passwordField.clear()
        confirmPasswordField.clear()
        protectProjectCheck.checked = false
        setDefaultLocationCheck.checked = false
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing16

        StandardTextField {
            id: projectNameField
            objectName: "welcomeProjectNameField"
            Layout.fillWidth: true
            labelText: "Project name"
            placeholderText: "e.g., Campus Core Lab"
            onAccepted: if (createButton.enabled) createButton.clicked()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            StandardTextField {
                id: projectLocationField
                objectName: "welcomeProjectLocationField"
                Layout.fillWidth: true
                labelText: "Project location"
                placeholderText: "Choose or enter a folder path"
                onAccepted: if (createButton.enabled) createButton.clicked()
            }

            StandardButton {
                objectName: "welcomeProjectLocationBrowseButton"
                Layout.alignment: Qt.AlignBottom
                text: "Browse…"
                onClicked: root.browseLocationRequested(projectLocationField.text)
            }
        }

        StandardCheckBox {
            id: setDefaultLocationCheck
            objectName: "welcomeSetDefaultProjectLocationCheck"
            visible: projectLocationField.text.trim().length > 0
                     && (root.locationIsDefault !== null
                         ? !root.locationIsDefault(projectLocationField.text)
                         : root.normalizedLocation(projectLocationField.text)
                           !== root.normalizedLocation(root.defaultProjectDirectory))
            text: "Use this location as the default for future projects"
        }

        StandardCheckBox {
            id: protectProjectCheck
            objectName: "welcomeProtectProjectCheck"
            text: "Protect project with a password"
            onToggled: {
                if (checked)
                    passwordField.forceActiveFocus()
                else {
                    passwordField.clear()
                    confirmPasswordField.clear()
                }
            }
        }

        StandardPasswordField {
            id: passwordField
            objectName: "welcomeProjectPasswordField"
            Layout.fillWidth: true
            visible: protectProjectCheck.checked
            labelText: "Password"
            placeholderText: "Enter a strong password"
            onAccepted: confirmPasswordField.forceActiveFocus()
        }

        StandardPasswordField {
            id: confirmPasswordField
            objectName: "welcomeProjectPasswordConfirmationField"
            Layout.fillWidth: true
            visible: protectProjectCheck.checked
            labelText: "Confirm password"
            placeholderText: "Enter the password again"
            onAccepted: if (createButton.enabled) createButton.clicked()
        }

        InlineMessage {
            Layout.fillWidth: true
            visible: protectProjectCheck.checked
                     && confirmPasswordField.text.length > 0
                     && passwordField.text !== confirmPasswordField.text
            message: "The passwords do not match."
            severity: "warning"
        }

        InlineMessage {
            Layout.fillWidth: true
            message: protectProjectCheck.checked
                     ? (LanguageState.isVietnamese
                        ? "Toàn bộ gói .ntp và mật khẩu thiết bị sẽ được mã hóa mạnh bằng Argon2id + AES-256-GCM. Mật khẩu không thể khôi phục nếu quên."
                        : "The complete .ntp package and credentials will be strongly protected with Argon2id + AES-256-GCM. The password is not stored or recoverable.")
                     : (LanguageState.isVietnamese
                        ? "Cảnh báo: Dự án chưa đặt mật khẩu. Mật khẩu thiết bị chỉ được làm rối kỹ thuật, không thể chống lại việc trích xuất file .ntp. Khuyến nghị nên đặt mật khẩu."
                        : "Warning: Project is unencrypted. Device credentials are only obfuscated and not protected against .ntp extraction. Setting a password is strongly recommended.")
            severity: protectProjectCheck.checked ? "info" : "warning"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Item { Layout.fillWidth: true }

            StandardButton {
                text: "Cancel"
                type: "Text"
                onClicked: root.reject()
            }

            StandardButton {
                id: createButton
                objectName: "welcomeCreateProjectConfirmButton"
                text: "Create Project"
                type: "Primary"
                enabled: projectNameField.text.trim().length > 0
                         && projectLocationField.text.trim().length > 0
                         && (!protectProjectCheck.checked
                             || (passwordField.text.length > 0
                                 && passwordField.text === confirmPasswordField.text))
                onClicked: {
                    root.createRequested(
                        projectNameField.text.trim(),
                        projectLocationField.text.trim(),
                        protectProjectCheck.checked ? passwordField.text : "",
                        setDefaultLocationCheck.visible
                            && setDefaultLocationCheck.checked
                    )
                }
            }
        }
    }
}
