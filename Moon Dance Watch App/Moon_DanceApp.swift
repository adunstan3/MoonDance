import SwiftUI

@main
struct MoondanceApp: App {
    @State private var settings: AppSettings
    @State private var board: BoardManager

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _board = State(initialValue: BoardManager(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(board)
                .tint(Theme.blue)
        }
    }
}
