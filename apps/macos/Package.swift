// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Assist",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Assist", targets: ["AIClipboard"])
    ],
    targets: [
        .executableTarget(
            name: "AIClipboard",
            path: "Sources/AIClipboard",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/Icons")
            ],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
