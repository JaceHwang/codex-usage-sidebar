import SwiftUI

@main
struct CodexUsageSidebarInstallerApp: App {
    @StateObject private var model = InstallerViewModel()

    var body: some Scene {
        WindowGroup {
            InstallerView(model: model)
                .frame(minWidth: 720, idealWidth: 760, minHeight: 500, idealHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
