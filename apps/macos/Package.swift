// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AIClipboard",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AIClipboard", targets: ["AIClipboard"])
    ],
    targets: [
        .executableTarget(
            name: "AIClipboard",
            path: "Sources/AIClipboard",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
