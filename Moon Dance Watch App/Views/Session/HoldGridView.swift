import SwiftUI

/// The 11 × 18 board: a dot per bolted hold (every position on the 2024 set,
/// 140 of the 198 on the 2016 set), a colored ring per problem hold
/// (green start, blue hand, red finish). Row 18 is at the top. It fills whatever
/// space it's given, so rows may be spaced a little further apart than columns.
struct HoldGridView: View {
    let holds: [Hold]
    /// "2016" or "2024": which positions have a hold on the wall.
    var holdSet: String?
    /// Your high point ("G13"): a bigger gold dot inside its ring.
    var highPoint: String?
    /// Holds with beta: a small white dot at the top right of the ring.
    var betaPositions: Set<String> = []

    var body: some View {
        let bolted = holdSet.flatMap { HoldImages.shared.info(for: $0) }.map { Set($0.positions) }
        return Canvas { context, size in
            let layout = GridLayout(size: size)
            let dot = layout.cell * 0.09
            for column in 0..<GridPosition.columns {
                for row in 1...GridPosition.rows {
                    if let bolted, let name = GridPosition(column: column, row: row)?.name, !bolted.contains(name) { continue }
                    let center = layout.center(column: column, row: row)
                    let rect = CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(white: 0.32)))
                }
            }
            if let highPoint, let position = GridPosition(highPoint) {
                let center = layout.center(column: position.column, row: position.row)
                let gold = layout.cell * 0.24
                context.fill(Path(ellipseIn: CGRect(x: center.x - gold, y: center.y - gold, width: gold * 2, height: gold * 2)),
                             with: .color(Theme.gold))
            }
            let radius = layout.cell * 0.46
            let line = max(1.5, layout.cell * 0.13)
            for hold in holds {
                guard let position = GridPosition(hold.position) else { continue }
                let center = layout.center(column: position.column, row: position.row)
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(Theme.color(for: hold.role)), lineWidth: line)
                if betaPositions.contains(hold.position) {
                    let r = max(1.5, layout.cell * 0.14)
                    let mark = CGPoint(x: center.x + radius * 0.75, y: center.y - radius * 0.75)
                    context.fill(Path(ellipseIn: CGRect(x: mark.x - r, y: mark.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Theme.white))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        func list(_ role: HoldRole) -> String {
            holds.filter { $0.role == role }.map(\.position).joined(separator: ", ")
        }
        let high = highPoint.map { " High point \($0)." } ?? ""
        return "Start \(list(.start)). Hands \(list(.hand)). Finish \(list(.finish)).\(high)"
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
