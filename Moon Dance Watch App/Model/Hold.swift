import Foundation

/// The role a hold plays in a problem. The LED box lights start holds green,
/// hand holds blue and finish holds red.
nonisolated enum HoldRole: String, Codable, Hashable, Sendable {
    case start, hand, finish
}

/// One hold of a problem: a grid position such as "D9" and its role.
nonisolated struct Hold: Codable, Hashable, Sendable {
    var position: String
    var role: HoldRole
}

/// A position on the 11 × 18 MoonBoard grid. Columns A–K are 0–10, rows are 1–18.
nonisolated struct GridPosition: Hashable, Sendable {
    static let columns = 11
    static let rows = 18
    static let columnLetters = Array("ABCDEFGHIJK")

    let column: Int
    let row: Int

    init?(column: Int, row: Int) {
        guard (0..<Self.columns).contains(column), (1...Self.rows).contains(row) else { return nil }
        self.column = column
        self.row = row
    }

    /// Parses names like "A5" or "k18" (case-insensitive).
    init?(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces).uppercased()
        guard let letter = trimmed.first,
              let column = Self.columnLetters.firstIndex(of: letter),
              let row = Int(trimmed.dropFirst()) else { return nil }
        self.init(column: column, row: row)
    }

    var name: String { "\(Self.columnLetters[column])\(row)" }
}
