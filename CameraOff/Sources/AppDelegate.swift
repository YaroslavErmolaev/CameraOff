import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let profileController = CameraProfileController()
    private let launchAtLoginController = LaunchAtLoginController()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBarController = StatusBarController(
            profileController: profileController,
            launchAtLoginController: launchAtLoginController
        )
        self.statusBarController = statusBarController

        profileController.onChange = { [weak statusBarController] isDisabled in
            statusBarController?.updateCameraState(isDisabled: isDisabled)
        }
        profileController.startMonitoring()
    }
}
