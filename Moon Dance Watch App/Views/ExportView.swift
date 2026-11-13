import SwiftData
import SwiftUI

/// Builds the CSV and opens the watch share sheet (Mail or Messages over cellular).
struct ExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var export: LogExport?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(Theme.blue)
                    Text(CSVExport.filename)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

                if let export, !export.isEmpty {
                    SectionLabel(text: "Send with")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ShareLink(item: export, preview: SharePreview(CSVExport.filename, image: Image(systemName: "doc.text"))) {
                        Label("Mail or Messages", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: LightControls.height)
                            .background(Theme.blue, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { settings.lastExport = .now })
                    Text("Pick Mail or Messages in the share sheet. Logs live only on this watch, so export every few weeks.")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle("Export")
        .onAppear { export = LogExport.make(context: context) }
    }

    private var summary: String {
        guard let export else { return "Preparing…" }
        if export.isEmpty { return "Nothing logged yet" }
        func plural(_ count: Int, _ one: String, _ many: String) -> String { "\(count) \(count == 1 ? one : many)" }
        var parts = [plural(export.entryCount, "entry", "entries")]
        if export.starCount > 0 { parts.append(plural(export.starCount, "star", "stars")) }
        if export.highPointCount > 0 { parts.append(plural(export.highPointCount, "high point", "high points")) }
        return parts.joined(separator: " · ") + " · both hold sets"
    }
}
