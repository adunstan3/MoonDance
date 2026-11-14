import SwiftData
import SwiftUI

/// Sessions grouped by calendar day: problems tried, attempts and sends.
/// Tapping a problem opens it in Session; the pen on the right of a row edits
/// that problem's log for the day (no swipe actions: History is one of the
/// sideways pages, so a swipe changes page).
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \LogEntry.date, order: .reverse) private var logs: [LogEntry]
    @Query private var marks: [HighPointMark]

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
                            // Two tap areas in one row (a List row is one button on
                            // watchOS, so these are tap gestures, not buttons).
                            HStack(spacing: 6) {
                                HistoryRow(problem: problem, day: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        session.show(problemID: problem.problemId, context: context, settings: settings)
                                        router.showSession()
                                    }
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color(white: 0.24)))
                                    .contentShape(Circle())
                                    .onTapGesture {
                                        router.push(.logEditor(problemID: problem.problemId, holdSet: holdSet,
                                                               day: day.date))
                                    }
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction {
                                session.show(problemID: problem.problemId, context: context, settings: settings)
                                router.showSession()
                            }
                            .accessibilityAction(named: "Edit log") {
                                router.push(.logEditor(problemID: problem.problemId, holdSet: holdSet, day: day.date))
                            }
                            .accessibilityIdentifier("historyRow")
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
