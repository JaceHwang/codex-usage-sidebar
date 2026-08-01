// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsageSidebar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SidebarCore", targets: ["SidebarCore"]),
        .executable(
            name: "CodexUsageSidebar",
            targets: ["CodexUsageSidebar"]
        )
    ],
    targets: [
        .target(name: "SidebarCore"),
        .executableTarget(
            name: "CodexUsageSidebar",
            dependencies: ["SidebarCore"]
        ),
        .testTarget(
            name: "SidebarCoreTests",
            dependencies: ["SidebarCore"]
        )
    ]
)
