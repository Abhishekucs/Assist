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
    dependencies: [
        .package(
            url: "https://github.com/argmaxinc/argmax-oss-swift.git",
            exact: "1.0.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "Assist",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/Assist",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/Assist.icns"),
                .copy("Resources/Brand"),
                .copy("Resources/Fonts"),
                .copy("Resources/Icons"),
                .copy("Resources/ThirdPartyNotices.md")
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
