import SwiftData
import SwiftUI

/// Loads the bundled problems on first launch, then shows the app.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @State private var loadState: LoadState = .loading

    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    var body: some View {
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
