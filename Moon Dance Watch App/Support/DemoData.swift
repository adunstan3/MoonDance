#if DEBUG
import Foundation
import SwiftData

/// Sample logs and projects for simulator screenshots (`-demoLogs YES`). DEBUG only.
enum DemoData {
    static func addLogs(context: ModelContext, settings: AppSettings) {
        guard (try? context.fetchCount(FetchDescriptor<LogEntry>())) == 0 else { return }
        let problems = SessionModel.fetch(context: context, holdSet: settings.holdSet, vGrade: settings.lastGrade,
                                          benchmarksOnly: false)
        guard problems.count >= 6 else { return }
        let calendar = Calendar.current
        let now = Date.now
        let earlier = calendar.date(byAdding: .day, value: -4, to: now) ?? now
        func log(_ problem: Problem, attempts: Int, sent: Bool, on day: Date, minutesAgo: Int) {
            for index in 0..<attempts {
                let date = day.addingTimeInterval(TimeInterval(-60 * (minutesAgo + attempts - index)))
                let isSend = sent && index == attempts - 1
                context.insert(LogEntry(problemId: problem.problemId, holdSet: problem.holdSet, date: date, isSend: isSend))
            }
        }
        log(problems[0], attempts: 4, sent: false, on: now, minutesAgo: 2)
        log(problems[1], attempts: 3, sent: true, on: now, minutesAgo: 20)
        log(problems[2], attempts: 2, sent: true, on: now, minutesAgo: 40)
        log(problems[3], attempts: 2, sent: false, on: now, minutesAgo: 60)
        log(problems[0], attempts: 3, sent: false, on: earlier, minutesAgo: 5)
        log(problems[4], attempts: 2, sent: true, on: earlier, minutesAgo: 30)
        log(problems[5], attempts: 4, sent: false, on: earlier, minutesAgo: 60)
        for (offset, problem) in [problems[0], problems[3], problems[5], problems[2]].enumerated() {
            context.insert(Project(problemId: problem.problemId, holdSet: problem.holdSet,
                                   dateAdded: now.addingTimeInterval(TimeInterval(-3600 * offset))))
        }
        try? context.save()
    }
}
#endif
