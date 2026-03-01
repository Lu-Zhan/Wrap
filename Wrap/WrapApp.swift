import SwiftUI
import SwiftData

@main
struct WrapApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ServerConnection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var sessionManager = SessionManager.shared
    @State private var appearance = TerminalAppearance.shared

    var body: some Scene {
        WindowGroup {
            ServerListView()
                .environment(sessionManager)
                .environment(appearance)
        }
        .modelContainer(sharedModelContainer)
    }
}
