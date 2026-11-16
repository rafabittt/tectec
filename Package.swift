// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TecTec",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Sparkle: atualizações automáticas fora da App Store (mesmo esquema do Legroom)
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "TecTec",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/TecTec",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
                // Sparkle.framework fica em TecTec.app/Contents/Frameworks
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ]
)
