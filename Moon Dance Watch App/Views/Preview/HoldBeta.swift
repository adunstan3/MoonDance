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

/// Writes one hold's beta. Saving blank text removes it.
struct HoldBetaEditor: View {
    let name: String
    let initial: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(name: String, initial: String, onSave: @escaping (String) -> Void) {
        self.name = name
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(name) beta")
                    .font(.headline)
                TextField("Heel hook, match, cross…", text: $draft, axis: .vertical)
                    .lineLimit(2...6)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("holdBetaField")
                Button {
                    onSave(draft)
                    dismiss()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Theme.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saveHoldBeta")
                if !initial.isEmpty {
                    Button(role: .destructive) {
                        onSave("")
                        dismiss()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.red)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
