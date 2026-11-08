import SwiftData
import SwiftUI

@main
struct MoondanceApp: App {
    @State private var settings: AppSettings
    @State private var board: BoardManager
    private let container: ModelContainer

    init() {
        let defaults = RuntimeEnvironment.userDefaults
        let settings = AppSettings(defaults: defaults)
        _settings = State(initialValue: settings)
        _board = State(initialValue: BoardManager(settings: settings))
        do {
            container = try Store.makeContainer(inMemory: RuntimeEnvironment.isUITesting)
        } catch {
            fatalError("Couldn't open the data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(board)
                .tint(Theme.blue)
        }
        .modelContainer(container)
    }
}

/// Facts about how the app was launched.
enum RuntimeEnvironment {
    /// UI tests launch with `-uiTesting`: fresh in-memory store and blank settings.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    static let userDefaults: UserDefaults = {
        guard isUITesting, let blank = UserDefaults(suiteName: "uiTesting") else { return .standard }
        blank.removePersistentDomain(forName: "uiTesting")
        return blank
    }()

    /// A debug launch argument such as `-openScreen log`.
    static func debugValue(_ key: String) -> String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: key)
        #else
        nil
        #endif
    }
}
