import SwiftData
import SwiftUI

/// Loads the bundled problems on first launch, then shows the app.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(AppModel.self) private var model
    @State private var loadState: LoadState = .loading
    /// The store error screen was dismissed with Continue.
    @State private var continuedWithoutStore = false

    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    var body: some View {
        if let error = model.storeError, !continuedWithoutStore {
            StoreErrorView(message: error) { continuedWithoutStore = true }
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            switch loadState {
            case .loading:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading problems…").foregroundStyle(Theme.secondaryText)
                }
            case .ready:
                MainView()
            case .failed(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.red)
                    Text("Couldn't load problems").font(.headline)
                    Text(message).font(.caption).foregroundStyle(Theme.secondaryText)
                    Button("Try again") { Task { await load() } }
                }
                .multilineTextAlignment(.center)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loadState = .loading
        // Let the loading view draw before the (one-time) import.
        await Task.yield()
        do {
            try SnapshotLoader.loadIfNeeded(into: context, from: SnapshotLoader.bundledSnapshotURL(),
                                            defaults: settings.defaults)
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

/// Shown instead of crashing when the saved log won't open. The app can carry on
/// with an empty log that isn't saved, or move the broken store aside so the next
/// launch starts a new one (the old files are kept on the watch).
struct StoreErrorView: View {
    let message: String
    let onContinue: () -> Void

    @State private var confirmNewLog = false
    @State private var movedAside = false
    @State private var moveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.red)
                Text("Couldn't open your log")
                    .font(.headline)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                if movedAside {
                    Text("Done. Close Moondance and open it again to start a new log. The old one is kept on the watch.")
                        .font(.footnote)
                } else {
                    Text("Nothing you log now will be saved.")
                        .font(.footnote)
                    Button("Continue anyway", action: onContinue)
                        .tint(Theme.blue)
                    Button("Start a new log", role: .destructive) { confirmNewLog = true }
                        .tint(Theme.red)
                }
                if let moveError {
                    Text(moveError)
                        .font(.caption2)
                        .foregroundStyle(Theme.red)
                }
            }
            .multilineTextAlignment(.center)
        }
        .confirmationDialog("Start a new, empty log? The old one stays on the watch but Moondance won't show it.",
                            isPresented: $confirmNewLog, titleVisibility: .visible) {
            Button("Start a new log", role: .destructive) {
                do {
                    try Store.moveAside()
                    movedAside = true
                } catch {
                    moveError = "Couldn't move it: \(error.localizedDescription)"
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
