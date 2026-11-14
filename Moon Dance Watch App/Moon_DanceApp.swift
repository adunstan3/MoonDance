import SwiftData
import SwiftUI

@main
struct MoondanceApp: App {
    private let model = AppModel.shared

    init() {
        LogExport.removeLeftoverFile()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.board)
                .environment(model.router)
                .environment(model.session)
                .environment(model.banner)
                .environment(model.climbing)
                .tint(Theme.blue)
        }
        .modelContainer(model.container)
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
