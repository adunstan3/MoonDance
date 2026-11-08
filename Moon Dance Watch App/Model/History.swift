import Foundation

/// History: logs grouped by calendar day in the watch's time zone, newest day first.
nonisolated enum History {
    struct Item: Sendable {
        let problemId: String
        let date: Date
        let isSend: Bool
    }

    struct ProblemDay: Identifiable, Equatable, Sendable {
        let problemId: String
        var attempts: Int
        var sends: Int
        /// Latest log of this problem that day; rows are ordered by it.
        var lastDate: Date

        var id: String { problemId }
        var isSent: Bool { sends > 0 }
    }

    struct Day: Identifiable, Equatable, Sendable {
        /// Start of the day.
        let date: Date
        var problems: [ProblemDay]

        var id: Date { date }
        var attempts: Int { problems.reduce(0) { $0 + $1.attempts } }
        var sends: Int { problems.reduce(0) { $0 + $1.sends } }
    }

    static func days(from items: [Item], calendar: Calendar = .current) -> [Day] {
        var byDay: [Date: [String: ProblemDay]] = [:]
        for item in items {
            let day = calendar.startOfDay(for: item.date)
            var problem = byDay[day]?[item.problemId]
                ?? ProblemDay(problemId: item.problemId, attempts: 0, sends: 0, lastDate: item.date)
            problem.attempts += 1
            if item.isSend { problem.sends += 1 }
            problem.lastDate = max(problem.lastDate, item.date)
            byDay[day, default: [:]][item.problemId] = problem
        }
        return byDay.map { date, problems in
            Day(date: date, problems: problems.values.sorted { $0.lastDate > $1.lastDate })
        }
        .sorted { $0.date > $1.date }
    }

    /// "TODAY", "YESTERDAY" or "WED, NOV 4".
    static func title(for day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted).weekday(.abbreviated).month(.abbreviated).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return day.formatted(style)
    }

    /// "5 problems · 14 attempts · 2 sends"
    static func summary(for day: Day) -> String {
        func plural(_ count: Int, _ word: String) -> String { "\(count) \(word)\(count == 1 ? "" : "s")" }
        return [plural(day.problems.count, "problem"), plural(day.attempts, "attempt"), plural(day.sends, "send")]
            .joined(separator: " · ")
    }
}
