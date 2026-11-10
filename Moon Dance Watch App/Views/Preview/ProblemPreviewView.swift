import SwiftData
import SwiftUI

/// Full-screen look at a problem with pictures of the real holds: only the
/// problem's holds, each ringed in its role's color (green start, blue hand,
/// red finish), with A–K and 1–18 around the edge.
///
/// Turn the Digital Crown to zoom (about the middle of the screen), drag to pan,
/// double-tap to see the whole board again.
struct ProblemPreviewView: View {
    let problemID: String

    @Environment(\.modelContext) private var context
    @State private var problem: Problem?
    @State private var zoom = 1.0
    @State private var centre = PreviewGeometry.boardCentre
    @State private var dragStart: CGPoint?
    @State private var size = CGSize(width: 1, height: 1)
    @FocusState private var crownFocused: Bool

    private var geometry: PreviewGeometry {
        PreviewGeometry(size: size, zoom: zoom, centre: centre)
    }

    var body: some View {
        Canvas { context, size in
            guard let problem else { return }
            let geometry = PreviewGeometry(size: size, zoom: zoom, centre: centre)
            Self.draw(problem, geometry: geometry, in: &context)
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .contentShape(Rectangle())
        .gesture(pan)
        .onTapGesture(count: 2) {
            withAnimation(.snappy) {
                zoom = 1
                centre = PreviewGeometry.boardCentre
            }
        }
        .focusable()
        .focused($crownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($zoom, from: PreviewGeometry.zoomRange.lowerBound,
                              through: PreviewGeometry.zoomRange.upperBound,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: zoom) { centre = geometry.clamped(centre) }
        .accessibilityElement()
        .accessibilityIdentifier("problemPreview")
        .accessibilityLabel(problem.map { "Hold pictures for \($0.name)" } ?? "Problem preview")
        .accessibilityValue("Zoom \(Int((zoom * 100).rounded())) percent")
        .accessibilityHint("Turn the Digital Crown to zoom, drag to look around, double-tap to reset")
        .onAppear {
            problem = SessionModel.problem(id: problemID, context: context)
            crownFocused = true
            // Screenshots: -previewZoom 3 -previewCentre 6,10 (board units).
            if let value = RuntimeEnvironment.debugValue("previewZoom"), let debugZoom = Double(value) {
                zoom = debugZoom
                let parts = RuntimeEnvironment.debugValue("previewCentre")?.split(separator: ",").compactMap { Double($0) }
                if let parts, parts.count == 2 { centre = CGPoint(x: parts[0], y: parts[1]) }
            }
        }
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = dragStart ?? geometry.centre
                dragStart = start
                let scale = geometry.scale
                centre = geometry.clamped(CGPoint(x: start.x - value.translation.width / scale,
                                                  y: start.y - value.translation.height / scale))
            }
            .onEnded { _ in dragStart = nil }
    }

    // MARK: - Drawing

    private static func draw(_ problem: Problem, geometry g: PreviewGeometry, in context: inout GraphicsContext) {
        let images = HoldImages.shared
        let scale = g.scale
        let inProblem = Set(problem.holds.compactMap { GridPosition($0.position) })

        // Faint dots where the other holds are, so the problem's place on the board reads.
        let dot = max(1, scale * 0.06)
        for column in 0..<GridPosition.columns {
            for row in 1...GridPosition.rows {
                guard let position = GridPosition(column: column, row: row), !inProblem.contains(position) else { continue }
                let centre = g.screenPoint(column: column, row: row)
                context.fill(Path(ellipseIn: CGRect(x: centre.x - dot, y: centre.y - dot, width: dot * 2, height: dot * 2)),
                             with: .color(Color(white: 0.22)))
            }
        }

        // The problem's holds, then a ring around each.
        let tile = (images.info(for: problem.holdSet)?.tileInCells ?? 1.44) * scale
        for hold in problem.holds {
            guard let position = GridPosition(hold.position) else { continue }
            let centre = g.screenPoint(column: position.column, row: position.row)
            if let sprite = images.sprite(for: position, holdSet: problem.holdSet) {
                let image = Image(decorative: sprite, scale: 1).interpolation(.high)
                context.draw(image, in: CGRect(x: centre.x - tile / 2, y: centre.y - tile / 2, width: tile, height: tile))
            }
        }
        let radius = scale * PreviewGeometry.ringRadius
        let line = max(1.5, scale * 0.07)
        for hold in problem.holds {
            guard let position = GridPosition(hold.position) else { continue }
            let centre = g.screenPoint(column: position.column, row: position.row)
            let ring = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(ring, with: .color(Theme.color(for: hold.role)), lineWidth: line)
        }

        drawLabels(g, in: &context)
    }

    /// A–K across the top and 1–18 down the left. When zoomed in they stay pinned
    /// to the edges, on a dark strip, so you always know where you are.
    private static func drawLabels(_ g: PreviewGeometry, in context: inout GraphicsContext) {
        let fontSize = min(max(g.scale * 0.5, 9), 15)
        let font = Font.system(size: fontSize, weight: .semibold, design: .rounded)
        let band = fontSize * 1.5

        let letterY = g.letterRowY(band: band)
        if letterY.pinned {
            context.fill(Path(CGRect(x: 0, y: 0, width: g.size.width, height: letterY.y + band / 2)),
                         with: .color(Theme.background.opacity(0.85)))
        }
        let numberX = g.numberColumnX(band: band)
        if numberX.pinned {
            context.fill(Path(CGRect(x: 0, y: 0, width: numberX.x + band / 2, height: g.size.height)),
                         with: .color(Theme.background.opacity(0.85)))
        }
        for column in 0..<GridPosition.columns {
            let x = g.screenPoint(column: column, row: 1).x
            guard x > numberX.x + band / 2, x < g.size.width else { continue }
            context.draw(Text(String(GridPosition.columnLetters[column])).font(font).foregroundStyle(Theme.secondaryText),
                         at: CGPoint(x: x, y: letterY.y))
        }
        for row in 1...GridPosition.rows {
            let y = g.screenPoint(column: 0, row: row).y
            guard y > letterY.y + band / 2, y < g.size.height else { continue }
            context.draw(Text("\(row)").font(font).foregroundStyle(Theme.secondaryText),
                         at: CGPoint(x: numberX.x, y: y))
        }
    }
}

/// Zoom and pan maths for the preview, in "board units" where one grid cell is 1.
/// The board is the 11 × 18 grid plus a gutter on the left (row numbers), one
/// along the top (column letters), and a small margin on the right and bottom.
nonisolated struct PreviewGeometry {
    static let gutterLeft = 1.0
    static let gutterTop = 1.0
    /// Space on the right and bottom so rings on column K and row 1 aren't cut off.
    static let margin = 0.25
    static let boardWidth = Double(GridPosition.columns) + gutterLeft + margin
    static let boardHeight = Double(GridPosition.rows) + gutterTop + margin
    static let boardCentre = CGPoint(x: boardWidth / 2, y: boardHeight / 2)
    static let zoomRange: ClosedRange<Double> = 1...4
    /// Room left at the top for the back button and clock, in points.
    static let topInset: CGFloat = 30
    /// Ring radius, in cells.
    static let ringRadius = 0.62

    let size: CGSize
    let zoom: Double
    /// The board point shown in the middle of the viewport (always kept in bounds).
    private(set) var centre: CGPoint

    init(size: CGSize, zoom: Double, centre: CGPoint) {
        self.size = size
        self.zoom = zoom
        self.centre = centre
        self.centre = clamped(centre)
    }

    /// The area the whole board fits in at zoom 1: below the clock line.
    var viewport: CGRect {
        CGRect(x: 0, y: Self.topInset, width: size.width, height: max(1, size.height - Self.topInset))
    }

    var fitScale: CGFloat { min(viewport.width / Self.boardWidth, viewport.height / Self.boardHeight) }

    /// Points per grid cell.
    var scale: CGFloat { fitScale * zoom }

    func screenPoint(boardX x: CGFloat, boardY y: CGFloat) -> CGPoint {
        CGPoint(x: viewport.midX + (x - centre.x) * scale, y: viewport.midY + (y - centre.y) * scale)
    }

    func screenPoint(column: Int, row: Int) -> CGPoint {
        screenPoint(boardX: Self.gutterLeft + CGFloat(column) + 0.5,
                    boardY: Self.gutterTop + CGFloat(GridPosition.rows - row) + 0.5)
    }

    /// Keeps the board on screen: where it's wider than the screen, no further
    /// than its edge. Where it fits across, it sits against the right edge, clear
    /// of the round back button at the top left.
    func clamped(_ point: CGPoint) -> CGPoint {
        let halfWidth = viewport.width / (2 * scale)
        let halfHeight = viewport.height / (2 * scale)
        let x = Self.boardWidth <= 2 * halfWidth
            ? Self.boardWidth - halfWidth
            : min(max(point.x, halfWidth), Self.boardWidth - halfWidth)
        let y = Self.boardHeight <= 2 * halfHeight
            ? Self.boardHeight / 2
            : min(max(point.y, halfHeight), Self.boardHeight - halfHeight)
        return CGPoint(x: x, y: y)
    }

    /// Where the column letters go: in their gutter, or pinned under the clock line
    /// once that gutter has scrolled off. `pinned` means "draw a strip behind them".
    func letterRowY(band: CGFloat) -> (y: CGFloat, pinned: Bool) {
        let natural = screenPoint(boardX: 0, boardY: Self.gutterTop / 2).y
        let pinned = viewport.minY + band / 2
        return (max(natural, pinned), natural < pinned - 2)
    }

    /// Where the row numbers go: in their gutter, or pinned to the left edge.
    func numberColumnX(band: CGFloat) -> (x: CGFloat, pinned: Bool) {
        let natural = screenPoint(boardX: Self.gutterLeft / 2, boardY: 0).x
        let pinned = band * 0.7
        return (max(natural, pinned), natural < pinned - 2)
    }
}
