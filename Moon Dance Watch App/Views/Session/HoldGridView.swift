import SwiftUI

/// The 11 × 18 board: a dot per position, a colored ring per hold
/// (green start, blue hand, red finish). Row 18 is at the top. It fills whatever
/// space it's given, so rows may be spaced a little further apart than columns.
struct HoldGridView: View {
    let holds: [Hold]

    var body: some View {
        Canvas { context, size in
            let layout = GridLayout(size: size)
            let dot = layout.cell * 0.09
            for column in 0..<GridPosition.columns {
                for row in 1...GridPosition.rows {
                    let center = layout.center(column: column, row: row)
                    let rect = CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(white: 0.32)))
                }
            }
            let radius = layout.cell * 0.46
            let line = max(1.5, layout.cell * 0.13)
            for hold in holds {
                guard let position = GridPosition(hold.position) else { continue }
                let center = layout.center(column: position.column, row: position.row)
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(Theme.color(for: hold.role)), lineWidth: line)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        func list(_ role: HoldRole) -> String {
            holds.filter { $0.role == role }.map(\.position).joined(separator: ", ")
        }
        return "Start \(list(.start)). Hands \(list(.hand)). Finish \(list(.finish))."
    }
}

/// Grid geometry shared by drawing and tests. Columns and rows each spread
/// across the full width and height.
nonisolated struct GridLayout {
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    init(size: CGSize) {
        cellWidth = size.width / CGFloat(GridPosition.columns)
        cellHeight = size.height / CGFloat(GridPosition.rows)
    }

    /// Size used for dots and rings, so they stay round.
    var cell: CGFloat { min(cellWidth, cellHeight) }

    func center(column: Int, row: Int) -> CGPoint {
        CGPoint(x: (CGFloat(column) + 0.5) * cellWidth,
                y: (CGFloat(GridPosition.rows - row) + 0.5) * cellHeight)
    }
}
