import SwiftData
import SwiftUI

/// Your beta for a problem: free-text notes. With no notes yet it opens straight
/// into editing; otherwise it shows them, with Edit. Saving blank text removes them.
/// Reached from Beta on Session and from the hold pictures.
struct BetaView: View {
    let problemID: String
    let holdSet: String

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query private var notes: [BetaNote]
    @State private var editing = false
    @State private var draft = ""
    @State private var started = false

    init(problemID: String, holdSet: String) {
        self.problemID = problemID
        self.holdSet = holdSet
        _notes = Query(filter: #Predicate<BetaNote> { $0.problemId == problemID && $0.holdSet == holdSet })
    }

    private var note: BetaNote? { notes.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(problemName)
                    .font(.headline)
                    .lineLimit(2)
                if editing {
                    editor
                } else if let note {
                    viewer(note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Beta")
        .onAppear {
            guard !started else { return }
            started = true
            // No notes yet: go straight to editing.
            if note == nil { startEditing() }
        }
    }

    private func viewer(_ note: BetaNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(.body)
                .foregroundStyle(Theme.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("betaText")
            Text("Updated \(note.updated.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            Button(action: startEditing) {
                Label("Edit", systemImage: "pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Theme.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editBeta")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("How to climb it", text: $draft, axis: .vertical)
                .lineLimit(3...10)
                .accessibilityIdentifier("betaField")
            Button {
                Logbook.setBeta(draft, problemId: problemID, holdSet: holdSet, in: context)
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    router.pop()
                } else {
                    editing = false
                }
            } label: {
                Label("Save", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Theme.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saveBeta")
            Button("Cancel") {
                if note == nil {
                    router.pop()
                } else {
                    editing = false
                }
            }
            .frame(maxWidth: .infinity)
            Text(note == nil ? "Tap the field to write with the keyboard, Scribble or dictation."
                             : "Clear the text and save to remove your beta.")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func startEditing() {
        draft = note?.text ?? ""
        editing = true
    }

    private var problemName: String {
        SessionModel.problem(id: problemID, context: context)?.name ?? problemID
    }
}
