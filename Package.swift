// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacVoiceInput",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacVoiceInput", targets: ["MacVoiceInput"])
    ],
    targets: [
        .executableTarget(
            name: "MacVoiceInput",
            path: "Sources/MacVoiceInput",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("Speech"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
