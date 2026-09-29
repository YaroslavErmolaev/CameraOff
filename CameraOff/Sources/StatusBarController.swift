import AppKit
import ServiceManagement

final class StatusBarController: NSObject {
    private let profileController: CameraProfileController
    private let launchAtLoginController: LaunchAtLoginController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private let stateItem = NSMenuItem()
    private let toggleCameraItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private var isCameraDisabled = false

    init(
        profileController: CameraProfileController,
        launchAtLoginController: LaunchAtLoginController
    ) {
        self.profileController = profileController
        self.launchAtLoginController = launchAtLoginController
        super.init()
        configureStatusItem()
        configureMenu()
        updateCameraState(isDisabled: false)
        updateLaunchAtLoginState()
    }

    func updateCameraState(isDisabled: Bool) {
        isCameraDisabled = isDisabled

        stateItem.title = isDisabled ? "Камера выключена" : "Камера включена"
        toggleCameraItem.title = isDisabled ? "Включить камеру" : "Выключить камеру…"

        if let button = statusItem.button {
            button.image = Self.circleImage(
                color: isDisabled ? .systemGray : .systemRed
            )
            button.toolTip = isDisabled
                ? "CameraOff — камера выключена"
                : "CameraOff — камера включена"
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func configureMenu() {
        let menu = NSMenu()

        stateItem.isEnabled = false
        menu.addItem(stateItem)

        toggleCameraItem.target = self
        toggleCameraItem.action = #selector(toggleCamera)
        menu.addItem(toggleCameraItem)

        menu.addItem(.separator())

        launchAtLoginItem.title = "Запускать при входе"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        let deviceManagementItem = NSMenuItem(
            title: "Управление профилями…",
            action: #selector(openDeviceManagement),
            keyEquivalent: ""
        )
        deviceManagementItem.target = self
        menu.addItem(deviceManagementItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Выйти из CameraOff",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        menu.delegate = self
    }

    @objc private func toggleCamera() {
        if isCameraDisabled {
            toggleCameraItem.isEnabled = false
            profileController.enableCamera { [weak self] _ in
                self?.toggleCameraItem.isEnabled = true
            }
        } else {
            do {
                try profileController.disableCamera()
            } catch {
                showError(
                    title: "Не удалось подготовить профиль",
                    message: error.localizedDescription
                )
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchAtLoginController.setEnabled(!launchAtLoginController.isEnabled)
            updateLaunchAtLoginState()

            if launchAtLoginController.status == .requiresApproval {
                launchAtLoginController.openSettings()
            }
        } catch {
            showError(
                title: "Не удалось изменить автозапуск",
                message: error.localizedDescription
            )
        }
    }

    @objc private func openDeviceManagement() {
        CameraProfileController.openDeviceManagementSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateLaunchAtLoginState() {
        switch launchAtLoginController.status {
        case .enabled:
            launchAtLoginItem.state = .on
            launchAtLoginItem.toolTip = nil
        case .requiresApproval:
            launchAtLoginItem.state = .mixed
            launchAtLoginItem.toolTip = "Нужно подтвердить в System Settings"
        default:
            launchAtLoginItem.state = .off
            launchAtLoginItem.toolTip = nil
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private static func circleImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        color.setFill()
        NSBezierPath(
            ovalIn: NSRect(x: 2, y: 2, width: 14, height: 14)
        ).fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        profileController.refresh()
        updateLaunchAtLoginState()
    }
}
