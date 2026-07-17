// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Assist",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Assist", targets: ["Assist"])
    ],
    targets: [
        .executableTarget(
            name: "Assist",
            path: "Sources/Assist",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/Assist.icns"),
                .copy("Resources/Brand"),
                .copy("Resources/Fonts"),
                .copy("Resources/Icons")
            ],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "AssistTests",
            dependencies: ["Assist"],
            path: "Tests/AssistTests"
        )
    ]
)
