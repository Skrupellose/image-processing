// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LiveCoverStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LiveCoverStudio",
            targets: ["LiveCoverStudio"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LiveCoverStudio",
            path: "Sources/LiveCoverStudio",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("Photos"),
                .linkedFramework("PhotosUI"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "LiveCoverStudioTests",
            dependencies: ["LiveCoverStudio"],
            path: "Tests/LiveCoverStudioTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
