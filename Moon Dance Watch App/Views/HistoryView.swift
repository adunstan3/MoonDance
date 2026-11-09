import SwiftData
import SwiftUI

/// Sessions grouped by calendar day: problems tried, attempts and sends.
/// Tapping a problem opens it in Session.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \LogEntry.date, order: .reverse) private var logs: [LogEntry]

    var body: some View {
        let holdSet = settings.holdSet.rawValue
        let items = logs.filter { $0.holdSet == holdSet }
            .map { History.Item(problemId: $0.problemId, date: $0.date, isSend: $0.isSend) }
        let days = History.days(from: items)
        let problems = SessionModel.problems(ids: Set(items.map(\.problemId)), context: context)
        List {
            if days.isEmpty {
                Text("Nothing logged on the \(settings.holdSet.label) set yet.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)
            }
            ForEach(days) { day in
                Section {
                    ForEach(day.problems) { entry in
                        if let problem = problems[entry.problemId] {
                            Button {
                                session.show(problemID: problem.problemId, context: context, settings: settings)
                                router.showSession()
                            } label: {
                                HistoryRow(problem: problem, day: entry)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 1) {
                        SectionLabel(text: History.title(for: day.date))
                        Text(History.summary(for: day))
                            .font(.footnote)
                            .foregroundStyle(Theme.white)
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

private struct HistoryRow: View {
    let problem: Problem
    let day: History.ProblemDay
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(problem.name).font(.headline).lineLimit(2)
                Text("\(problem.grade(settings.gradeScale)) · \(day.attempts) attempt\(day.attempts == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 2)
            if day.isSent {
                Label("Sent", systemImage: "checkmark.circle")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.green)
            } else {
                Text("\(day.attempts)×")
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}
