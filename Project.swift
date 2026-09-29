import ProjectDescription

let project = Project(
    name: "CameraOff",
    targets: [
        .target(
            name: "CameraOff",
            destinations: .macOS,
            product: .app,
            bundleId: "com.yaroslavermolaev.CameraOff",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .file(path: "CameraOff/Info.plist"),
            sources: ["CameraOff/Sources/**"],
            resources: [],
            dependencies: []
        )
    ]
)
