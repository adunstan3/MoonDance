import AppIntents

// The Action Button can't be read inside an app (and long press belongs to the
// system), so the button runs one of these through Settings › Action Button ›
// Shortcut. Each opens Moondance and acts on the problem on the Session screen.

/// Follows Settings › Action Button: +1 attempt, or Light it.
struct ActionButtonIntent: AppIntent {
    static let title: LocalizedStringResource = "Moondance Action"
    static let description = IntentDescription("Logs an attempt or lights the problem, as chosen in Moondance Settings.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.performActionButton()
        return .result()
    }
}

struct LogAttemptIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Attempt"
    static let description = IntentDescription("Adds one attempt to the problem on the Session screen.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.router.showSession()
        AppModel.shared.logAttempt()
        return .result()
    }
}

struct MarkSentIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Sent"
    static let description = IntentDescription("Logs a send of the problem on the Session screen.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.router.showSession()
        AppModel.shared.markSent()
        return .result()
    }
}

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
        AppShortcut(intent: ActionButtonIntent(),
                    phrases: ["\(.applicationName) action"],
                    shortTitle: "Moondance Action", systemImageName: "figure.climbing")
        AppShortcut(intent: LogAttemptIntent(),
                    phrases: ["Log an attempt in \(.applicationName)", "\(.applicationName) attempt"],
                    shortTitle: "Log Attempt", systemImageName: "plus.circle")
        AppShortcut(intent: MarkSentIntent(),
                    phrases: ["Mark sent in \(.applicationName)", "\(.applicationName) sent"],
                    shortTitle: "Mark Sent", systemImageName: "checkmark.circle")
        AppShortcut(intent: LightItIntent(),
                    phrases: ["Light it in \(.applicationName)", "\(.applicationName) light it"],
                    shortTitle: "Light It", systemImageName: "lightbulb")
    }
}
