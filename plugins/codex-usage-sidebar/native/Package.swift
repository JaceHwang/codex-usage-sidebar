// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsageSidebar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SidebarCore", targets: ["SidebarCore"]),
        .library(name: "InstallerCore", targets: ["InstallerCore"]),
        .executable(
            name: "CodexUsageSidebar",
            targets: ["CodexUsageSidebar"]
        )
    ],
    targets: [
        .target(name: "SidebarCore"),
        .target(name: "InstallerCore"),
        .executableTarget(
            name: "CodexUsageSidebar",
            dependencies: ["SidebarCore"]
        ),
        .testTarget(
            name: "SidebarCoreTests",
            dependencies: ["SidebarCore"]
        ),
        .testTarget(
            name: "InstallerCoreTests",
            dependencies: ["InstallerCore"]
        )
    ]
)
