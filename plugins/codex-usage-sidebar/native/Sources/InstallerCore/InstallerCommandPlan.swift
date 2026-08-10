import Foundation

public enum InstallerCommandPlan {
    public static let pluginSelector = "codex-usage-sidebar@codex-usage-sidebar"
    public static let marketplaceName = "codex-usage-sidebar"

    public static func install(
        paths: InstallerPaths,
        marketplaceAlreadyConfigured: Bool
    ) -> [CommandSpec] {
        var commands: [CommandSpec] = []
        if !marketplaceAlreadyConfigured {
            commands.append(
                CommandSpec(
                    executable: paths.codexExecutable,
                    arguments: [
                        "plugin", "marketplace", "add",
                        paths.stableMarketplaceRoot.path,
                        "--json",
                    ]
                )
            )
        }
        commands.append(
            CommandSpec(
                executable: paths.codexExecutable,
                arguments: ["plugin", "add", pluginSelector, "--json"]
            )
        )
        commands.append(companionCommand("ensure", paths: paths))
        return commands
    }

    public static func status(paths: InstallerPaths) -> CommandSpec {
        CommandSpec(executable: paths.installedControlScript, arguments: ["status"])
    }

    public static func repair(paths: InstallerPaths) -> CommandSpec {
        companionCommand("repair", paths: paths)
    }

    public static func loginStatus(paths: InstallerPaths) -> CommandSpec {
        codexLoginCommand(["login", "status"], paths: paths)
    }

    public static func marketplaceList(paths: InstallerPaths) -> CommandSpec {
        CommandSpec(
            executable: paths.codexExecutable,
            arguments: ["plugin", "marketplace", "list", "--json"]
        )
    }

    public static func login(paths: InstallerPaths) -> CommandSpec {
        codexLoginCommand(["login"], paths: paths)
    }

    public static func uninstall(
        paths: InstallerPaths,
        removeMarketplace: Bool
    ) -> [CommandSpec] {
        var commands = [
            CommandSpec(
                executable: paths.codexExecutable,
                arguments: ["plugin", "remove", pluginSelector, "--json"]
            ),
        ]
        if removeMarketplace {
            commands.append(
                CommandSpec(
                    executable: paths.codexExecutable,
                    arguments: ["plugin", "marketplace", "remove", marketplaceName]
                )
            )
        }
        commands.append(
            CommandSpec(executable: paths.installedControlScript, arguments: ["uninstall"])
        )
        return commands
    }

    private static func companionCommand(
        _ action: String,
        paths: InstallerPaths
    ) -> CommandSpec {
        CommandSpec(
            executable: paths.controlScript,
            arguments: [
                action,
                "--plugin-root", paths.pluginRoot.path,
                "--plugin-data", paths.pluginData.path,
            ]
        )
    }

    private static func codexLoginCommand(
        _ arguments: [String],
        paths: InstallerPaths
    ) -> CommandSpec {
        CommandSpec(
            executable: paths.codexExecutable,
            arguments: arguments,
            environment: ["CODEX_HOME": paths.codexHome.path]
        )
    }
}
