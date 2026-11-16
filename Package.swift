// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TecTec",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TecTec",
            path: "Sources/TecTec",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
