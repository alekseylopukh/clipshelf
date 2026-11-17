// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClipsyKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ClipsyKit", targets: ["Capture"])
    ],
    targets: [
        .target(name: "Capture"),
        .testTarget(name: "CaptureTests", dependencies: ["Capture"])
    ]
)
