// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ListeningTimer",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "ListeningTimer", targets: ["ListeningTimer"])
    ],
    targets: [
        .target(
            name: "ListeningCore"
        ),
        .executableTarget(
            name: "ListeningTimer",
            dependencies: ["ListeningCore"]
        ),
        .executableTarget(
            name: "CoreSelfTests",
            dependencies: ["ListeningCore"]
        ),
        .testTarget(
            name: "ListeningCoreTests",
            dependencies: ["ListeningCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
