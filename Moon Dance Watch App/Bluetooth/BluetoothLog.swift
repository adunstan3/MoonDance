import Foundation
import Observation
import os

/// An on-screen record of every Bluetooth step and error, for the gym visit.
@Observable
final class BluetoothLog {
    struct Entry: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let text: String
        let isError: Bool
    }

    static let maxEntries = 400

    private(set) var entries: [Entry] = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.andrewdunstan.Moondance", category: "Bluetooth")

    func add(_ text: String, isError: Bool = false) {
        entries.append(Entry(date: .now, text: text, isError: isError))
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        if isError {
            logger.error("\(text, privacy: .public)")
        } else {
            logger.info("\(text, privacy: .public)")
        }
    }

    func error(_ text: String) { add(text, isError: true) }

    func clear() { entries.removeAll() }

    /// Plain text of the whole log, for sharing.
    var text: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return entries.map { entry in
            "\(formatter.string(from: entry.date)) \(entry.isError ? "ERROR " : "")\(entry.text)"
        }.joined(separator: "\n")
    }
}
