import Foundation

/// How a box is shown to the climber.
nonisolated enum BoardIdentity {
    /// Newer boxes show a 12-digit ID; if the advertised name contains a long run
    /// of digits, that's the ID. Otherwise fall back to the start of Core
    /// Bluetooth's identifier so two boxes can still be told apart.
    static func displayID(name: String?, identifier: String) -> String {
        if let name, let digits = name.firstMatch(of: #/\d{6,}/#) {
            return String(digits.output)
        }
        return String(identifier.prefix(8)).uppercased()
    }

    /// The advertised name without the ID digits ("MoonBoard 4829…" → "MoonBoard").
    static func displayName(_ name: String) -> String {
        let trimmed = name.replacing(#/\d{6,}/#, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return trimmed.isEmpty ? "MoonBoard LED" : trimmed
    }
}
