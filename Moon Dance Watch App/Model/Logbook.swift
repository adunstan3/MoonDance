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
