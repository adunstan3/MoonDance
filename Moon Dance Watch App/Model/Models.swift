import Foundation
import SwiftData

/// A MoonBoard problem from the bundled snapshot. Read-only: it is replaced
/// wholesale when a new snapshot ships, so nothing user-made lives here.
@Model
final class Problem {
    /// The dataset's stable problem id (boardsesh's climb uuid). Logs and projects
    /// refer to problems by this id so they survive a new snapshot.
    @Attribute(.unique) var problemId: String
    /// `HoldSet.rawValue` ("2016" or "2024").
    var holdSet: String
    var name: String
    var setter: String
    var fontGrade: String
    var vGrade: Int
    var isBenchmark: Bool
    var repeats: Int
    var holds: [Hold]

    init(problemId: String, holdSet: String, name: String, setter: String, fontGrade: String,
         vGrade: Int, isBenchmark: Bool, repeats: Int, holds: [Hold]) {
        self.problemId = problemId
        self.holdSet = holdSet
        self.name = name
        self.setter = setter
        self.fontGrade = fontGrade
        self.vGrade = vGrade
        self.isBenchmark = isBenchmark
        self.repeats = repeats
        self.holds = holds
    }

    /// "V5" or "6C+", per the Grades setting.
    func grade(_ scale: GradeScale) -> String {
        Grades.name(vGrade: vGrade, font: fontGrade, scale: scale)
    }
}

/// One attempt or send. A send also counts as an attempt.
@Model
final class LogEntry {
    var id: UUID
    var problemId: String
    var holdSet: String
    var date: Date
    var isSend: Bool

    init(id: UUID = UUID(), problemId: String, holdSet: String, date: Date = .now, isSend: Bool) {
        self.id = id
        self.problemId = problemId
        self.holdSet = holdSet
        self.date = date
        self.isSend = isSend
    }
}

/// A starred problem.
@Model
final class Project {
    var problemId: String
    var holdSet: String
    var dateAdded: Date

    init(problemId: String, holdSet: String, dateAdded: Date = .now) {
        self.problemId = problemId
        self.holdSet = holdSet
        self.dateAdded = dateAdded
    }
}

/// The furthest hold reached on a problem: one per problem and hold set, set by
/// long-pressing a hand hold in the hold-picture preview.
@Model
final class HighPoint {
    var problemId: String
    var holdSet: String
    /// Grid position, e.g. "G13".
    var position: String
    var date: Date

    init(problemId: String, holdSet: String, position: String, date: Date = .now) {
        self.problemId = problemId
        self.holdSet = holdSet
        self.position = position
        self.date = date
    }
}

/// Each time a high point is marked, for History. `HighPoint` keeps only the
/// current one; these keep every marking.
@Model
final class HighPointMark {
    var problemId: String
    var holdSet: String
    /// Grid position, e.g. "G13".
    var position: String
    var date: Date

    init(problemId: String, holdSet: String, position: String, date: Date = .now) {
        self.problemId = problemId
        self.holdSet = holdSet
        self.position = position
        self.date = date
    }
}

/// Your beta pinned to one hold of a problem ("heel hook"): one per problem,
/// hold set and position, written from the hold pictures.
@Model
final class BetaNote {
    var problemId: String
    var holdSet: String
    /// Grid position, e.g. "E9".
    var position: String = ""
    var text: String
    var updated: Date

    init(problemId: String, holdSet: String, position: String, text: String, updated: Date = .now) {
        self.problemId = problemId
        self.holdSet = holdSet
        self.position = position
        self.text = text
        self.updated = updated
    }
}

enum Store {
    static let models: [any PersistentModel.Type] = [Problem.self, LogEntry.self, Project.self, HighPoint.self,
                                                     HighPointMark.self, BetaNote.self]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Renames the store's files (default.store and its -shm and -wal files) so the
    /// next launch starts an empty log. The old files stay next to it, renamed
    /// "….broken-<time>", so the log can still be recovered from the watch.
    static func moveAside(now: Date = .now) throws {
        let path = ModelConfiguration(schema: Schema(models)).url.path
        let stamp = Int(now.timeIntervalSince1970)
        let files = FileManager.default
        for suffix in ["", "-shm", "-wal"] where files.fileExists(atPath: path + suffix) {
            try files.moveItem(atPath: path + suffix, toPath: path + ".broken-\(stamp)" + suffix)
        }
    }
}
