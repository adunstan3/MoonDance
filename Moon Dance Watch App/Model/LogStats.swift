import Foundation

/// Attempts and sends per problem, worked out from the log.
/// A send also counts as an attempt.
nonisolated struct ProblemStats: Equatable, Sendable {
    var attempts = 0
    var sends = 0

    var isSent: Bool { sends > 0 }
}

nonisolated struct LogStats: Sendable {
    struct Item: Sendable {
        let problemId: String
        let holdSet: String
        let isSend: Bool
    }

    private(set) var byProblem: [String: ProblemStats] = [:]

    init(items: [Item], holdSet: String? = nil) {
        for item in items where holdSet == nil || item.holdSet == holdSet {
            var stats = byProblem[item.problemId, default: ProblemStats()]
            stats.attempts += 1
            if item.isSend { stats.sends += 1 }
            byProblem[item.problemId] = stats
        }
    }

    subscript(problemId: String) -> ProblemStats { byProblem[problemId, default: ProblemStats()] }
}

extension LogStats {
    init(entries: [LogEntry], holdSet: String? = nil) {
        self.init(items: entries.map { Item(problemId: $0.problemId, holdSet: $0.holdSet, isSend: $0.isSend) },
                  holdSet: holdSet)
    }
}
