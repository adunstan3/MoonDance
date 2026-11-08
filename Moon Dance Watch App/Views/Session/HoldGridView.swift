import SwiftUI

/// The 11 × 18 board: a dot per position, a colored ring per hold
/// (green start, blue hand, red finish). Row 18 is at the top.
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
        .aspectRatio(CGFloat(GridPosition.columns) / CGFloat(GridPosition.rows), contentMode: .fit)
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

/// Grid geometry shared by drawing and tests.
nonisolated struct GridLayout {
    let cell: CGFloat
    let origin: CGPoint

    init(size: CGSize) {
        let columns = CGFloat(GridPosition.columns)
        let rows = CGFloat(GridPosition.rows)
        cell = min(size.width / columns, size.height / rows)
        origin = CGPoint(x: (size.width - cell * columns) / 2, y: (size.height - cell * rows) / 2)
    }

    func center(column: Int, row: Int) -> CGPoint {
        CGPoint(x: origin.x + (CGFloat(column) + 0.5) * cell,
                y: origin.y + (CGFloat(GridPosition.rows - row) + 0.5) * cell)
    }
}
