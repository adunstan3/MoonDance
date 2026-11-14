import SwiftData
import SwiftUI

/// The callout beside a tapped hold: its coordinates, its beta (or "No beta yet")
/// and a small pen circle that writes or changes it. Tapping the text also edits.
struct HoldCallout: View {
    let name: String
    let text: String?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.white)
                Spacer(minLength: 4)
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.blue))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text == nil ? "Add beta for \(name)" : "Edit beta for \(name)")
                .accessibilityIdentifier("editHoldBeta")
            }
            Text(text ?? "No beta yet")
                .font(.footnote)
                .foregroundStyle(text == nil ? Theme.secondaryText : Theme.white)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("holdBetaText")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.white.opacity(0.7), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("holdCallout")
    }
}

/// Writes one hold's beta, saving as you go (blank text removes it). The back
/// button returns to the hold pictures. Opened on a hold with no beta, the red
/// button is Cancel (throws away anything written); otherwise it's Remove.
struct HoldBetaEditor: View {
    let problemID: String
    let holdSet: String
    let position: String

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @State private var draft = ""
    /// The hold had no beta when this opened.
    @State private var isNew = true
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Heel hook, match, cross…", text: $draft, axis: .vertical)
                    .lineLimit(2...6)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("holdBetaField")
                    .onChange(of: draft) { save() }
                Button(role: .destructive) {
                    draft = ""
                    save()
                    router.pop()
                } label: {
                    Text(isNew ? "Cancel" : "Remove")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Theme.red.opacity(0.2), in: Capsule())
                        .foregroundStyle(Theme.red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(isNew ? "cancelHoldBeta" : "removeHoldBeta")
            }
        }
        .navigationTitle("\(position) beta")
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let existing = Logbook.beta(problemId: problemID, holdSet: holdSet, in: context)[position]
            isNew = existing == nil
            draft = existing ?? ""
        }
        .onDisappear(perform: save)
    }

    private func save() {
        guard loaded else { return }
        let current = Logbook.beta(problemId: problemID, holdSet: holdSet, in: context)[position] ?? ""
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != current else { return }
        Logbook.setBeta(draft, problemId: problemID, holdSet: holdSet, position: position, in: context)
    }
}
