// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClaudeUsageMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClaudeUsageMonitor", targets: ["ClaudeUsageMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageMonitor",
            path: "Sources/ClaudeUsageMonitor"
        ),
        .testTarget(
            name: "ClaudeUsageMonitorTests",
            dependencies: ["ClaudeUsageMonitor"],
            path: "Tests/ClaudeUsageMonitorTests",
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5]
)
