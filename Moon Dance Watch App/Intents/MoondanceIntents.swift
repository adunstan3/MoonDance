import AppIntents

/// Lights the problem on the Session screen. Available as a shortcut (Siri, or
/// Watch Settings › Action Button › Shortcut); it opens Moondance to do it.
struct LightItIntent: AppIntent {
    static let title: LocalizedStringResource = "Light It"
    static let description = IntentDescription("Lights the problem on the Session screen on the board.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.router.showSession()
        AppModel.shared.lightCurrent()
        return .result()
    }
}

struct MoondanceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LightItIntent(),
                    phrases: ["Light it in \(.applicationName)", "\(.applicationName) light it"],
                    shortTitle: "Light It", systemImageName: "lightbulb")
    }
}
