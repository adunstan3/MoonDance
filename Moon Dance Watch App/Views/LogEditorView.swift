import SwiftData
import SwiftUI

/// One problem's attempts and sends on one day, for fixing the log (from a
/// History row's Edit swipe). Tap an entry to switch it between attempt and send;
/// swipe to delete it; Delete all clears the day for this problem.
struct LogEditorView: View {
    let problemID: String
    let holdSet: String
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query private var entries: [LogEntry]
    @State private var confirmDeleteAll = false

    init(problemID: String, holdSet: String, day: Date, calendar: Calendar = .current) {
        self.problemID = problemID
        self.holdSet = holdSet
        self.day = day
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(filter: #Predicate<LogEntry> {
            $0.problemId == problemID && $0.holdSet == holdSet && $0.date >= start && $0.date < end
        }, sort: \LogEntry.date)
    }

    var body: some View {
        List {
            Section {
                ForEach(entries) { entry in
                    Button {
                        Logbook.setSend(!entry.isSend, entryID: entry.id, in: context)
                    } label: {
                        EntryRow(entry: entry)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Logbook.delete([entry], in: context)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(Theme.red)
                    }
                    .accessibilityHint(entry.isSend ? "Tap to make it an attempt" : "Tap to make it a send")
                }
            } header: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(problemName)
                        .font(.headline)
                        .foregroundStyle(Theme.white)
                        .lineLimit(2)
                    SectionLabel(text: History.title(for: day))
                }
                .textCase(nil)
            } footer: {
                Text("Tap to switch attempt and send. Swipe left to delete.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }

            if entries.isEmpty {
                Text("Nothing logged on this day.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)
            } else {
                Button(role: .destructive) {
                    confirmDeleteAll = true
                } label: {
                    Label("Delete all \(entries.count)", systemImage: "trash")
                        .foregroundStyle(Theme.red)
                }
                .accessibilityIdentifier("deleteAllEntries")
            }
        }
        .navigationTitle("Edit log")
        .confirmationDialog("Delete \(entries.count) entr\(entries.count == 1 ? "y" : "ies") for this day?",
                            isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Logbook.delete(entries, in: context)
                router.pop()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var problemName: String {
        SessionModel.problem(id: problemID, context: context)?.name ?? problemID
    }
}

private struct EntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack {
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.headline.monospacedDigit())
            Spacer(minLength: 4)
            if entry.isSend {
                Label("Send", systemImage: "checkmark.circle")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.green)
            } else {
                Label("Attempt", systemImage: "arrow.counterclockwise")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.blue)
            }
        }
        .padding(.vertical, 2)
    }
}
