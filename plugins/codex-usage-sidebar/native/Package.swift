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
        ),
        .executable(
            name: "CodexUsageSidebarInstaller",
            targets: ["CodexUsageSidebarInstaller"]
        )
    ],
    targets: [
        .target(name: "SidebarCore"),
        .target(name: "InstallerCore"),
        .executableTarget(
            name: "CodexUsageSidebar",
            dependencies: ["SidebarCore"],
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "CodexUsageSidebarInstaller",
            dependencies: ["InstallerCore"]
        ),
        .testTarget(
            name: "SidebarCoreTests",
            dependencies: ["SidebarCore"]
        ),
        .testTarget(
            name: "CodexUsageSidebarTests",
            dependencies: ["CodexUsageSidebar"]
        ),
        .testTarget(
            name: "InstallerCoreTests",
            dependencies: ["InstallerCore", "CodexUsageSidebarInstaller"]
        )
    ]
)
