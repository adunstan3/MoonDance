import SwiftData
import SwiftUI

/// Sessions grouped by calendar day: problems tried, attempts and sends.
/// Tapping a problem opens it in Session. Swiping a row edits or deletes that
/// problem's log for the day.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \LogEntry.date, order: .reverse) private var logs: [LogEntry]
    @Query private var marks: [HighPointMark]
    @State private var pendingDelete: PendingDelete?

    /// A History row whose day of logs is waiting for "Delete?" to be confirmed.
    struct PendingDelete: Identifiable {
        let problemId: String
        let name: String
        let day: Date
        let count: Int
        var id: String { "\(problemId)-\(day.timeIntervalSince1970)" }
    }

    var body: some View {
        let holdSet = settings.holdSet.rawValue
        let items = logs.filter { $0.holdSet == holdSet }
            .map { History.Item(problemId: $0.problemId, date: $0.date, isSend: $0.isSend) }
            + marks.filter { $0.holdSet == holdSet }
            .map { History.Item(problemId: $0.problemId, date: $0.date, isSend: false, highPoint: $0.position) }
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
                            .swipeActions(edge: .trailing) {
                                Button {
                                    router.push(.logEditor(problemID: problem.problemId, holdSet: holdSet, day: day.date))
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Theme.blue)
                                Button {
                                    pendingDelete = PendingDelete(problemId: problem.problemId, name: problem.name,
                                                                  day: day.date,
                                                                  count: entry.attempts + (entry.highPoint == nil ? 0 : 1))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(Theme.red)
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
        .confirmationDialog(deleteTitle, isPresented: Binding(get: { pendingDelete != nil },
                                                              set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { pending in
            Button("Delete", role: .destructive) {
                let holdSet = settings.holdSet.rawValue
                Logbook.delete(Logbook.entries(problemId: pending.problemId, holdSet: holdSet, on: pending.day,
                                               in: context), in: context)
                Logbook.delete(Logbook.highPointMarks(problemId: pending.problemId, holdSet: holdSet, on: pending.day,
                                                      in: context), in: context)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var deleteTitle: String {
        guard let pending = pendingDelete else { return "" }
        return "Delete \(pending.count) log entr\(pending.count == 1 ? "y" : "ies") for \(pending.name) on \(History.title(for: pending.day))?"
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
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                if let highPoint = day.highPoint {
                    Label("High point \(highPoint)", systemImage: "flag.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            Spacer(minLength: 2)
            if day.isSent {
                Label("Sent", systemImage: "checkmark.circle")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.green)
            } else if day.attempts > 0 {
                Text("\(day.attempts)×")
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        let grade = problem.grade(settings.gradeScale)
        guard day.attempts > 0 else { return grade }
        return "\(grade) · \(day.attempts) attempt\(day.attempts == 1 ? "" : "s")"
    }
}
