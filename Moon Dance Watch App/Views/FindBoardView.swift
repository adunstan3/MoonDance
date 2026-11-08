import CoreBluetooth
import SwiftUI

/// Lists nearby LED boxes with their IDs; the chosen one is saved so later
/// sessions connect to it automatically. Shown on first launch, from Settings,
/// and when Light it is tapped with no board saved.
struct FindBoardView: View {
    @Environment(BoardManager.self) private var board
    @Environment(AppSettings.self) private var settings
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router

    @State private var selection: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                scanStatus
                ForEach(boards) { found in
                    BoardRow(board: found, isSelected: found.id == selection)
                        .onTapGesture { selection = found.id }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(found.id == selection ? .isSelected : [])
                }
                Button(action: useSelected) {
                    Text("Use this board")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: LightControls.height)
                        .background(selection == nil ? Theme.card : Theme.blue, in: Capsule())
                        .foregroundStyle(selection == nil ? Theme.secondaryText : .white)
                }
                .buttonStyle(.plain)
                .disabled(selection == nil)
                Text("Saved for next time; change it in Settings")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                if !settings.hasSavedBoard {
                    Button("Not now") { router.pop() }
                        .font(.footnote)
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        }
        .navigationTitle("Find board")
        .onAppear {
            board.startScan()
            #if DEBUG
            if RuntimeEnvironment.debugValue("demoBoards") != nil { board.debugAddDemoBoards() }
            #endif
            if let saved = settings.boardID { selection = UUID(uuidString: saved) }
        }
        .onDisappear { board.stopScan() }
        .onChange(of: boards.map(\.id)) { _, ids in
            if selection == nil, let first = ids.first { selection = first }
        }
    }

    private var boards: [DiscoveredBoard] {
        board.discovered.filter { $0.looksLikeBoard || settings.showAllDevices }
    }

    @ViewBuilder
    private var scanStatus: some View {
        let unusable = board.bluetoothState == .unsupported || board.bluetoothState == .unauthorized
            || board.bluetoothState == .poweredOff
        HStack(spacing: 6) {
            Circle()
                .fill(unusable ? Theme.red : Theme.blue)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(unusable ? Theme.red : Theme.secondaryText)
        }
    }

    private var statusText: String {
        switch board.bluetoothState {
        case .unsupported: "Bluetooth isn't available here"
        case .unauthorized: "Allow Bluetooth in Settings › Privacy"
        case .poweredOff: "Turn Bluetooth on"
        default: "Scanning for LED boxes…"
        }
    }

    private func useSelected() {
        guard let selection, let chosen = board.discovered.first(where: { $0.id == selection }) else { return }
        board.stopScan()
        board.save(chosen)
        if let pending = session.pendingLight {
            session.pendingLight = nil
            session.litProblemID = pending.problemID
            board.light(pending.holds)
        }
        router.pop()
    }
}

private struct BoardRow: View {
    let board: DiscoveredBoard
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(BoardIdentity.displayName(board.name))
                    .font(.headline)
                    .lineLimit(1)
                Text(BoardIdentity.displayID(name: board.name, identifier: board.id.uuidString))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                Image(systemName: "cellularbars", variableValue: signalLevel)
                Text(board.signal.rawValue)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(board.signal == .far ? Theme.secondaryText : Theme.white)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isSelected ? Theme.blue : .clear, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private var signalLevel: Double {
        switch board.signal {
        case .near: 1
        case .medium: 0.6
        case .far: 0.3
        }
    }
}
