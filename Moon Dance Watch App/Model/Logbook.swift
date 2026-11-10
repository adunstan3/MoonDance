import Foundation
import SwiftData

/// Writing attempts, sends and project stars.
enum Logbook {
    @discardableResult
    static func logAttempt(_ problem: Problem, in context: ModelContext, at date: Date = .now) -> LogEntry {
        insert(problem, isSend: false, in: context, at: date)
    }

    /// A send also counts as an attempt.
    @discardableResult
    static func logSend(_ problem: Problem, in context: ModelContext, at date: Date = .now) -> LogEntry {
        insert(problem, isSend: true, in: context, at: date)
    }

    static func undo(entryID: UUID, in context: ModelContext) {
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.id == entryID })
        for entry in (try? context.fetch(descriptor)) ?? [] {
            context.delete(entry)
        }
        try? context.save()
    }

    /// A removed log entry, kept so Undo can put it back exactly.
    struct Snapshot: Equatable, Sendable {
        let id: UUID
        let problemId: String
        let holdSet: String
        let date: Date
        let isSend: Bool
    }

    /// Removes every attempt and send of a problem on its hold set.
    @discardableResult
    static func clearLog(for problem: Problem, in context: ModelContext) -> [Snapshot] {
        let id = problem.problemId
        let set = problem.holdSet
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.problemId == id && $0.holdSet == set })
        let entries = (try? context.fetch(descriptor)) ?? []
        let snapshots = entries.map {
            Snapshot(id: $0.id, problemId: $0.problemId, holdSet: $0.holdSet, date: $0.date, isSend: $0.isSend)
        }
        entries.forEach(context.delete)
        try? context.save()
        return snapshots
    }

    static func restore(_ snapshots: [Snapshot], in context: ModelContext) {
        for snapshot in snapshots {
            context.insert(LogEntry(id: snapshot.id, problemId: snapshot.problemId, holdSet: snapshot.holdSet,
                                    date: snapshot.date, isSend: snapshot.isSend))
        }
        try? context.save()
    }

    static func stats(for problem: Problem, in context: ModelContext) -> ProblemStats {
        let id = problem.problemId
        let set = problem.holdSet
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.problemId == id && $0.holdSet == set })
        let entries = (try? context.fetch(descriptor)) ?? []
        return ProblemStats(attempts: entries.count, sends: entries.filter(\.isSend).count)
    }

    static func isProject(_ problem: Problem, in context: ModelContext) -> Bool {
        !projects(for: problem, in: context).isEmpty
    }

    /// Stars or unstars a problem. Returns whether it's now a project.
    /// Sending a project keeps the star; only this removes it.
    @discardableResult
    static func toggleProject(_ problem: Problem, in context: ModelContext, at date: Date = .now) -> Bool {
        let existing = projects(for: problem, in: context)
        if existing.isEmpty {
            context.insert(Project(problemId: problem.problemId, holdSet: problem.holdSet, dateAdded: date))
            try? context.save()
            return true
        }
        existing.forEach(context.delete)
        try? context.save()
        return false
    }

    /// The problem's high point (a grid position such as "G13"), if any.
    static func highPoint(for problem: Problem, in context: ModelContext) -> String? {
        highPoints(for: problem, in: context).first?.position
    }

    /// Sets the problem's one high point, replacing any other; nil removes it.
    static func setHighPoint(_ position: String?, for problem: Problem, in context: ModelContext,
                             at date: Date = .now) {
        highPoints(for: problem, in: context).forEach(context.delete)
        if let position {
            context.insert(HighPoint(problemId: problem.problemId, holdSet: problem.holdSet, position: position, date: date))
        }
        try? context.save()
    }

    private static func highPoints(for problem: Problem, in context: ModelContext) -> [HighPoint] {
        let id = problem.problemId
        let set = problem.holdSet
        let descriptor = FetchDescriptor<HighPoint>(predicate: #Predicate { $0.problemId == id && $0.holdSet == set })
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func projects(for problem: Problem, in context: ModelContext) -> [Project] {
        let id = problem.problemId
        let set = problem.holdSet
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.problemId == id && $0.holdSet == set })
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func insert(_ problem: Problem, isSend: Bool, in context: ModelContext, at date: Date) -> LogEntry {
        let entry = LogEntry(problemId: problem.problemId, holdSet: problem.holdSet, date: date, isSend: isSend)
        context.insert(entry)
        try? context.save()
        return entry
    }
}
