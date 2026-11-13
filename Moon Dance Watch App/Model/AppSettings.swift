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

/// App settings, kept in UserDefaults (see CLAUDE.md, Data).
@Observable
final class AppSettings {
    enum Keys {
        static let holdSet = "holdSet"
        static let boardID = "boardID"
        static let boardName = "boardName"
        static let lastExport = "lastExport"
        static let lastGrade = "lastGrade"
        static let benchmarksOnly = "benchmarksOnly"
        static let gradeScale = "gradeScale"
        static let bleFlags = "bleFlags"
        static let showAllDevices = "showAllDevices"
        static let climberHeight = "climberHeightInches"
    }

    static let defaultGrade = 5
    /// The climber drawn beside the hold pictures for scale: 6 ft by default.
    static let defaultHeight = 72
    static let heightRange = 48...90

    /// "6′0″"
    static func heightText(_ inches: Int) -> String { "\(inches / 12)′\(inches % 12)″" }

    static func centimetres(_ inches: Int) -> Int { Int((Double(inches) * 2.54).rounded()) }

    @ObservationIgnored let defaults: UserDefaults

    var holdSet: HoldSet { didSet { defaults.set(holdSet.rawValue, forKey: Keys.holdSet) } }
    /// The saved LED box: Core Bluetooth's identifier for it on this watch.
    var boardID: String? { didSet { defaults.set(boardID, forKey: Keys.boardID) } }
    /// The name the saved box advertised (shows its ID on newer boxes).
    var boardName: String? { didSet { defaults.set(boardName, forKey: Keys.boardName) } }
    var lastExport: Date? { didSet { defaults.set(lastExport, forKey: Keys.lastExport) } }
    /// Last V grade picked in the grade picker (V5 on first launch).
    var lastGrade: Int { didSet { defaults.set(lastGrade, forKey: Keys.lastGrade) } }
    var benchmarksOnly: Bool { didSet { defaults.set(benchmarksOnly, forKey: Keys.benchmarksOnly) } }
    /// Show grades as V ("V5") or Font ("6C+").
    var gradeScale: GradeScale { didSet { defaults.set(gradeScale.rawValue, forKey: Keys.gradeScale) } }
    /// Optional flags packet sent before each problem (e.g. "D"). Empty by default.
    var bleFlags: String { didSet { defaults.set(bleFlags, forKey: Keys.bleFlags) } }
    /// Bluetooth log option: list every device during a scan, not only LED boxes.
    var showAllDevices: Bool { didSet { defaults.set(showAllDevices, forKey: Keys.showAllDevices) } }
    /// Your height in inches, for the climber in the hold pictures.
    var climberHeight: Int { didSet { defaults.set(climberHeight, forKey: Keys.climberHeight) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        holdSet = HoldSet(rawValue: defaults.string(forKey: Keys.holdSet) ?? "") ?? .mb2024
        boardID = defaults.string(forKey: Keys.boardID)
        boardName = defaults.string(forKey: Keys.boardName)
        lastExport = defaults.object(forKey: Keys.lastExport) as? Date
        let savedGrade = defaults.object(forKey: Keys.lastGrade) as? Int ?? Self.defaultGrade
        lastGrade = Grades.range.contains(savedGrade) ? savedGrade : Self.defaultGrade
        benchmarksOnly = defaults.bool(forKey: Keys.benchmarksOnly)
        gradeScale = GradeScale(rawValue: defaults.string(forKey: Keys.gradeScale) ?? "") ?? .v
        bleFlags = defaults.string(forKey: Keys.bleFlags) ?? ""
        showAllDevices = defaults.bool(forKey: Keys.showAllDevices)
        let savedHeight = defaults.object(forKey: Keys.climberHeight) as? Int ?? Self.defaultHeight
        climberHeight = Self.heightRange.contains(savedHeight) ? savedHeight : Self.defaultHeight
    }

    var hasSavedBoard: Bool { boardID != nil }

    func forgetBoard() {
        boardID = nil
        boardName = nil
    }
}
