import SwiftUI

/// Every Bluetooth step and error, plus Test send / Clear / Scan for the gym visit.
/// Reached from Settings.
struct BluetoothLogView: View {
    @Environment(BoardManager.self) private var board
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        List {
            Section {
                StatusRow(status: board.status, isScanning: board.isScanning)
                Button {
                    board.light(BoardProtocol.testProblem)
                } label: {
                    Label("Test send", systemImage: "lightbulb.fill")
                }
                .foregroundStyle(Theme.blue)
                .disabled(board.isBusy)
                Button {
                    board.clearBoard()
                } label: {
                    Label("Clear board", systemImage: "xmark.circle.fill")
                }
                .foregroundStyle(Theme.red)
                .disabled(board.isBusy)
                Button {
                    board.isScanning ? board.stopScan() : board.startScan()
                } label: {
                    Label(board.isScanning ? "Stop scan" : "Scan", systemImage: "antenna.radiowaves.left.and.right")
                }
            } footer: {
                Text("Test send lights a 2024 problem: start D5 F4, hands E8 H10 G13 D15, finish F18.")
            }

            Section("Options") {
                Toggle("Show all devices", isOn: $settings.showAllDevices)
                Picker("Flags packet", selection: $settings.bleFlags) {
                    Text("None").tag("")
                    Text("~D*").tag("D")
                }
                ShareLink(item: board.log.text) {
                    Label("Share log", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    board.log.clear()
                } label: {
                    Label("Clear log", systemImage: "trash")
                }
            }

            if !board.discovered.isEmpty {
                Section("Seen") {
                    ForEach(board.discovered) { device in
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text("\(device.signal.rawValue) · \(device.rssi) dBm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Log") {
                if board.log.entries.isEmpty {
                    Text("Nothing yet").foregroundStyle(.secondary)
                }
                ForEach(board.log.entries.reversed()) { entry in
                    LogRow(entry: entry)
                }
            }
        }
        .navigationTitle("Bluetooth log")
        .onDisappear { board.stopScan() }
    }
}

private struct StatusRow: View {
    let status: BoardManager.Status
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.headline)
        }
        .accessibilityElement(children: .combine)
    }

    private var text: String {
        switch status {
        case .idle: isScanning ? "Scanning" : "Idle"
        case .connecting: "Connecting"
        case .sending: "Sending"
        case .lit: "Lit"
        case .cleared: "Cleared"
        case .failed: "Failed"
        }
    }

    private var color: Color {
        switch status {
        case .idle, .cleared: Theme.idle
        case .connecting, .sending: Theme.blue
        case .lit: Theme.green
        case .failed: Theme.red
        }
    }
}

private struct LogRow: View {
    let entry: BluetoothLog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.date, format: .dateTime.hour().minute().second())
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 4) {
                if entry.isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                Text(entry.text)
            }
            .font(.caption)
            .foregroundStyle(entry.isError ? Theme.red : .primary)
        }
    }
}
