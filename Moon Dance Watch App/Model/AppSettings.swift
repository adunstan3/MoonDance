import Foundation
import Observation

/// Which MoonBoard hold set is on the wall.
nonisolated enum HoldSet: String, Codable, CaseIterable, Identifiable, Sendable {
    case mb2016 = "2016"
    case mb2024 = "2024"

    var id: String { rawValue }

    /// Short label used in headers and the Settings picker.
    var label: String {
        switch self {
        case .mb2016: "2016"
        case .mb2024: "2024 · 40°"
        }
    }
}

/// What the Ultra's Action Button does.
nonisolated enum ActionButtonMode: String, CaseIterable, Identifiable, Sendable {
    case logAttempts
    case lightIt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logAttempts: "Log attempts"
        case .lightIt: "Light it"
        }
    }
}

/// App settings, kept in UserDefaults (see CLAUDE.md, Data).
@Observable
final class AppSettings {
    enum Keys {
        static let holdSet = "holdSet"
        static let actionButtonMode = "actionButtonMode"
        static let boardID = "boardID"
        static let boardName = "boardName"
        static let lastExport = "lastExport"
        static let lastGrade = "lastGrade"
        static let benchmarksOnly = "benchmarksOnly"
        static let bleFlags = "bleFlags"
        static let showAllDevices = "showAllDevices"
    }

    static let defaultGrade = 5

    @ObservationIgnored let defaults: UserDefaults

    var holdSet: HoldSet { didSet { defaults.set(holdSet.rawValue, forKey: Keys.holdSet) } }
    var actionButtonMode: ActionButtonMode { didSet { defaults.set(actionButtonMode.rawValue, forKey: Keys.actionButtonMode) } }
    /// The saved LED box: Core Bluetooth's identifier for it on this watch.
    var boardID: String? { didSet { defaults.set(boardID, forKey: Keys.boardID) } }
    /// The name the saved box advertised (shows its ID on newer boxes).
    var boardName: String? { didSet { defaults.set(boardName, forKey: Keys.boardName) } }
    var lastExport: Date? { didSet { defaults.set(lastExport, forKey: Keys.lastExport) } }
    /// Last V grade picked in the grade picker (V5 on first launch).
    var lastGrade: Int { didSet { defaults.set(lastGrade, forKey: Keys.lastGrade) } }
    var benchmarksOnly: Bool { didSet { defaults.set(benchmarksOnly, forKey: Keys.benchmarksOnly) } }
    /// Optional flags packet sent before each problem (e.g. "D"). Empty by default.
    var bleFlags: String { didSet { defaults.set(bleFlags, forKey: Keys.bleFlags) } }
    /// Bluetooth log option: list every device during a scan, not only LED boxes.
    var showAllDevices: Bool { didSet { defaults.set(showAllDevices, forKey: Keys.showAllDevices) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        holdSet = HoldSet(rawValue: defaults.string(forKey: Keys.holdSet) ?? "") ?? .mb2024
        actionButtonMode = ActionButtonMode(rawValue: defaults.string(forKey: Keys.actionButtonMode) ?? "") ?? .logAttempts
        boardID = defaults.string(forKey: Keys.boardID)
        boardName = defaults.string(forKey: Keys.boardName)
        lastExport = defaults.object(forKey: Keys.lastExport) as? Date
        lastGrade = defaults.object(forKey: Keys.lastGrade) as? Int ?? Self.defaultGrade
        benchmarksOnly = defaults.bool(forKey: Keys.benchmarksOnly)
        bleFlags = defaults.string(forKey: Keys.bleFlags) ?? ""
        showAllDevices = defaults.bool(forKey: Keys.showAllDevices)
    }

    var hasSavedBoard: Bool { boardID != nil }

    func forgetBoard() {
        boardID = nil
        boardName = nil
    }
}
