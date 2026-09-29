import AppKit
import Foundation

final class CameraProfileController {
    static let profileIdentifier = "com.yaroslavermolaev.CameraOff.restrictions"

    private(set) var isCameraDisabled = false
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    private var refreshInProgress = false

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard !refreshInProgress else { return }
        refreshInProgress = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let installed = Self.profileIsInstalled()
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshInProgress = false
                self.isCameraDisabled = installed
                self.onChange?(installed)
            }
        }
    }

    func disableCamera() throws {
        let profileURL = try Self.writeRestrictionProfile()
        NSWorkspace.shared.open(profileURL)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Self.openDeviceManagementSettings()
        }
    }

    func enableCamera(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let removed = Self.removeRestrictionProfile()
            DispatchQueue.main.async {
                if !removed {
                    Self.openDeviceManagementSettings()
                }
                self?.refresh()
                completion(removed)
            }
        }
    }

    static func openDeviceManagementSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Profiles-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func profileIsInstalled() -> Bool {
        let result = runProfiles(arguments: ["show", "-type", "configuration"])
        return result.output.contains("profileIdentifier: \(profileIdentifier)")
    }

    private static func removeRestrictionProfile() -> Bool {
        _ = runProfiles(arguments: [
            "remove",
            "-type", "configuration",
            "-identifier", profileIdentifier,
            "-user", NSUserName(),
        ])
        return !profileIsInstalled()
    }

    private static func runProfiles(arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(data: data, encoding: .utf8) ?? ""
        )
    }

    private static func writeRestrictionProfile() throws -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("CameraOff", isDirectory: true)

        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )

        let profileURL = baseURL.appendingPathComponent(
            "CameraOff-Camera-Disabled.mobileconfig"
        )
        try restrictionProfileXML.write(
            to: profileURL,
            atomically: true,
            encoding: .utf8
        )
        return profileURL
    }

    private static let restrictionProfileXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>PayloadContent</key>
        <array>
            <dict>
                <key>PayloadDisplayName</key>
                <string>Disable Camera</string>
                <key>PayloadIdentifier</key>
                <string>com.yaroslavermolaev.CameraOff.restrictions.camera</string>
                <key>PayloadType</key>
                <string>com.apple.applicationaccess</string>
                <key>PayloadUUID</key>
                <string>9BDF2E0B-238D-42D5-86B8-F8F32C3AC7D2</string>
                <key>PayloadVersion</key>
                <integer>1</integer>
                <key>allowCamera</key>
                <false/>
            </dict>
        </array>
        <key>PayloadDescription</key>
        <string>Disables camera access for all applications for this user.</string>
        <key>PayloadDisplayName</key>
        <string>CameraOff — Camera Disabled</string>
        <key>PayloadIdentifier</key>
        <string>com.yaroslavermolaev.CameraOff.restrictions</string>
        <key>PayloadOrganization</key>
        <string>CameraOff</string>
        <key>PayloadRemovalDisallowed</key>
        <false/>
        <key>PayloadScope</key>
        <string>User</string>
        <key>PayloadType</key>
        <string>Configuration</string>
        <key>PayloadUUID</key>
        <string>4C50B3F5-82BB-4CE0-9941-E1864547C12B</string>
        <key>PayloadVersion</key>
        <integer>1</integer>
    </dict>
    </plist>
    """
}
