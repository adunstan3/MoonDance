import Foundation
import SwiftData

/// Writing attempts, sends, project stars and high points, and editing the log.
enum Logbook {
    /// Called when a save fails. AppModel shows a red banner and writes it to the
    /// on-screen log, so a lost entry doesn't go unnoticed.
    static var onSaveError: ((Error) -> Void)?

    /// Saves, reporting a failure through `onSaveError`. Returns whether it worked.
    @discardableResult
    static func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            onSaveError?(error)
            return false
        }
    }

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
        entries(ids: [entryID], in: context).forEach(context.delete)
        save(context)
    }

    /// Turns the problem's latest send back into an attempt (the try still counts).
    /// Earlier attempts and sends are kept. Returns the entry changed, or nil if
    /// the problem has no send.
    @discardableResult
    static func unsendLatest(_ problem: Problem, in context: ModelContext) -> UUID? {
        let id = problem.problemId
        let set = problem.holdSet
        var descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.problemId == id && $0.holdSet == set && $0.isSend },
                                                   sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let latest = try? context.fetch(descriptor).first else { return nil }
        latest.isSend = false
        save(context)
        return latest.id
    }

    /// Marks an entry as a send or an attempt (log editing, and undoing an unsend).
    static func setSend(_ isSend: Bool, entryID: UUID, in context: ModelContext) {
        for entry in entries(ids: [entryID], in: context) {
            entry.isSend = isSend
        }
        save(context)
    }

    /// A problem's attempts and sends on one calendar day, oldest first.
    static func entries(problemId: String, holdSet: String, on day: Date, calendar: Calendar = .current,
                        in context: ModelContext) -> [LogEntry] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { $0.problemId == problemId && $0.holdSet == holdSet && $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Deletes log entries (log editing).
    static func delete(_ entries: [LogEntry], in context: ModelContext) {
        entries.forEach(context.delete)
        save(context)
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
            save(context)
            return true
        }
        existing.forEach(context.delete)
        save(context)
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
        save(context)
    }

    private static func entries(ids: [UUID], in context: ModelContext) -> [LogEntry] {
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { ids.contains($0.id) })
        return (try? context.fetch(descriptor)) ?? []
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
        save(context)
        return entry
    }
}
