import Foundation
import Observation
import SwiftData

/// The problem list for the current hold set and grade, and which problem the
/// Session screen is showing. The Digital Crown steps `index`.
@Observable
final class SessionModel {
    static let lastProblemKey = "lastProblemID"

    private(set) var problems: [Problem] = []
    private(set) var index = 0
    /// The problem most recently sent to the board with Light it.
    var litProblemID: String?

    /// Light it was tapped before a board was saved: light this once Find board saves one.
    struct PendingLight: Equatable {
        let problemID: String
        let holds: [Hold]
    }

    var pendingLight: PendingLight?

    var current: Problem? { problems.indices.contains(index) ? problems[index] : nil }

    /// "3 / 42"
    var positionText: String { problems.isEmpty ? "0 / 0" : "\(index + 1) / \(problems.count)" }

    /// Reloads the list for the current settings, keeping the given (or current,
    /// or last-viewed) problem selected when it's still in the list.
    func reload(context: ModelContext, settings: AppSettings, keeping problemID: String? = nil) {
        let keep = problemID ?? current?.problemId ?? settings.defaults.string(forKey: Self.lastProblemKey)
        problems = Self.fetch(context: context, holdSet: settings.holdSet, vGrade: settings.lastGrade,
                              benchmarksOnly: settings.benchmarksOnly)
        index = problems.firstIndex { $0.problemId == keep } ?? 0
        remember(settings: settings)
    }

    /// Moves to a list position (clamped). Used by the Crown and list taps.
    func select(index newIndex: Int, settings: AppSettings) {
        guard !problems.isEmpty else { return }
        let clamped = min(max(newIndex, 0), problems.count - 1)
        guard clamped != index else { return }
        index = clamped
        remember(settings: settings)
    }

    func step(by offset: Int, settings: AppSettings) {
        select(index: index + offset, settings: settings)
    }

    /// Shows a problem from anywhere (Projects, History), switching the grade
    /// filter to it if needed.
    func show(problemID: String, context: ModelContext, settings: AppSettings) {
        if let found = problems.firstIndex(where: { $0.problemId == problemID }) {
            select(index: found, settings: settings)
            return
        }
        guard let problem = Self.problem(id: problemID, context: context) else { return }
        if let set = HoldSet(rawValue: problem.holdSet), set != settings.holdSet {
            settings.holdSet = set
        }
        settings.lastGrade = problem.vGrade
        if settings.benchmarksOnly && !problem.isBenchmark {
            settings.benchmarksOnly = false
        }
        reload(context: context, settings: settings, keeping: problemID)
    }

    private func remember(settings: AppSettings) {
        settings.defaults.set(current?.problemId, forKey: Self.lastProblemKey)
    }

    // MARK: - Queries

    static func fetch(context: ModelContext, holdSet: HoldSet, vGrade: Int, benchmarksOnly: Bool) -> [Problem] {
        let set = holdSet.rawValue
        let predicate: Predicate<Problem>
        if benchmarksOnly {
            predicate = #Predicate { $0.holdSet == set && $0.vGrade == vGrade && $0.isBenchmark }
        } else {
            predicate = #Predicate { $0.holdSet == set && $0.vGrade == vGrade }
        }
        let descriptor = FetchDescriptor(predicate: predicate,
                                         sortBy: [SortDescriptor(\.repeats, order: .reverse), SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func problem(id: String, context: ModelContext) -> Problem? {
        var descriptor = FetchDescriptor<Problem>(predicate: #Predicate { $0.problemId == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Problems by id, for Projects and History rows.
    static func problems(ids: Set<String>, context: ModelContext) -> [String: Problem] {
        guard !ids.isEmpty else { return [:] }
        let list = Array(ids)
        let descriptor = FetchDescriptor<Problem>(predicate: #Predicate { list.contains($0.problemId) })
        let found = (try? context.fetch(descriptor)) ?? []
        return Dictionary(found.map { ($0.problemId, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
