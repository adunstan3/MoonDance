import SwiftData
import SwiftUI

/// Full-screen look at a problem with pictures of the real holds: only the
/// problem's holds, with the start holds outlined in green and the finish in red,
/// and A–K and 1–18 around the edge.
///
/// Turn the Digital Crown to zoom (about the middle of the screen), drag to pan
/// (a little past every edge, so corners clear the screen's rounding), double-tap
/// to see the whole board again. A small "Back" on the clock's line goes back.
///
/// Long-press a hand hold to make it your high point (outlined in gold; one per
/// problem, so it replaces the last). Long-pressing the finish logs a send; start
/// holds can't be a high point.
///
/// Beta lives on the holds. Tap one of the problem's holds for a callout with its
/// coordinates and its beta, and a pen to write or change it (empty grid points do
/// nothing). Holds with beta get a small white mark. The pen circle beside Back
/// shows every note at once, next to its hold.
struct ProblemPreviewView: View {
    let problemID: String
    /// Open with every note showing (Beta on Session).
    let showingBeta: Bool

    init(problemID: String, showingBeta: Bool = false) {
        self.problemID = problemID
        self.showingBeta = showingBeta
        _betaNotes = Query(filter: #Predicate<BetaNote> { $0.problemId == problemID })
    }

    static let longPressDuration: Duration = .milliseconds(500)
    /// How far a finger can drift before a touch becomes a pan, in points.
    static let moveSlop: CGFloat = 6
    static let doubleTapInterval: TimeInterval = 0.35
    /// Callout width, in points.
    static let calloutWidth: CGFloat = 150

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(AppModel.self) private var model
    @Query private var highPoints: [HighPoint]
    @Query private var betaNotes: [BetaNote]
    @State private var selected: GridPosition?
    @State private var showAllBeta = false
    @State private var editing: EditTarget?
    /// The open callout's height, measured, so it can sit just above its hold.
    @State private var calloutHeight: CGFloat = 70
    @State private var problem: Problem?
    @State private var zoom = 1.0
    @State private var centre = PreviewGeometry.boardCentre
    @State private var touch: Touch?
    @State private var lastTap: Date?
    @State private var message: Message?
    @FocusState private var crownFocused: Bool

    /// One finger on the screen. It becomes a pan once it moves, a long press if
    /// it stays put for half a second, and otherwise a tap.
    private struct Touch {
        let id = UUID()
        let start: CGPoint
        /// The board point in the middle of the screen when the touch began.
        let centre: CGPoint
        var moved = false
        var longPressed = false
    }

    /// The hold whose beta is being written.
    struct EditTarget: Identifiable {
        let position: GridPosition
        var id: String { position.name }
    }

    /// A short note after a long press ("High point G13", "Sent", …).
    private struct Message: Equatable {
        let id = UUID()
        let text: String
    }

    /// This problem's beta, by hold ("E9" → "heel hook").
    private var beta: [String: String] {
        guard let problem else { return [:] }
        var result: [String: String] = [:]
        for note in betaNotes where note.holdSet == problem.holdSet && !note.position.isEmpty {
            result[note.position] = note.text
        }
        return result
    }

    private var highPoint: String? {
        guard let problem else { return nil }
        return highPoints.first { $0.problemId == problem.problemId && $0.holdSet == problem.holdSet }?.position
    }

    var body: some View {
        // One size (the whole screen) for drawing, panning and zoom limits.
        GeometryReader { proxy in
            let size = proxy.size
            let beta = beta
            Canvas { context, canvasSize in
                guard let problem else { return }
                let geometry = PreviewGeometry(size: canvasSize, zoom: zoom, centre: centre)
                Self.draw(problem, highPoint: highPoint, beta: beta, showAllBeta: showAllBeta,
                          selected: selected, geometry: geometry, in: &context)
            }
            .contentShape(Rectangle())
            .gesture(touches(size: size))
            .accessibilityElement()
            .accessibilityIdentifier("problemPreview")
            .accessibilityLabel(problem.map { "Hold pictures for \($0.name)" } ?? "Problem preview")
            .accessibilityValue("Zoom \(Int((zoom * 100).rounded())) percent")
            .accessibilityHint("Turn the Digital Crown to zoom, drag to look around, double-tap to reset, "
                + "tap a hold for its beta, long-press a hold to mark your high point")
            // An overlay, so the callout never changes the board's layout.
            .overlay(alignment: .topLeading) {
                if let selected {
                    callout(for: selected, text: beta[selected.name], size: size)
                }
            }
            .onChange(of: zoom) { centre = PreviewGeometry(size: size, zoom: zoom, centre: centre).centre }
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { topBar }
        .overlay(alignment: .bottom) { messageView }
        .toolbar(.hidden, for: .navigationBar)
        .focusable()
        .focused($crownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($zoom, from: PreviewGeometry.zoomRange.lowerBound,
                              through: PreviewGeometry.zoomRange.upperBound,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .sheet(item: $editing) { target in
            HoldBetaEditor(name: target.position.name, initial: beta[target.position.name] ?? "") { text in
                guard let problem else { return }
                Logbook.setBeta(text, problemId: problem.problemId, holdSet: problem.holdSet,
                                position: target.position.name, in: context)
            }
        }
        .onAppear {
            problem = SessionModel.problem(id: problemID, context: context)
            crownFocused = true
            if showingBeta {
                showAllBeta = true
                if beta.isEmpty { show("Tap a hold to add beta") }
            }
            // Screenshots: -previewSelect E9 opens a hold's callout; -previewBeta YES shows every note.
            if let name = RuntimeEnvironment.debugValue("previewSelect"), let position = GridPosition(name) {
                selected = position
            }
            if RuntimeEnvironment.debugValue("previewBeta") != nil { showAllBeta = true }
            // Screenshots: -previewZoom 3 -previewCentre 6,10 (board units).
            if let value = RuntimeEnvironment.debugValue("previewZoom"), let debugZoom = Double(value) {
                zoom = debugZoom
                let parts = RuntimeEnvironment.debugValue("previewCentre")?.split(separator: ",").compactMap { Double($0) }
                if let parts, parts.count == 2 { centre = CGPoint(x: parts[0], y: parts[1]) }
            }
        }
    }

    /// The tapped hold's coordinates and beta, beside it: above if there's room,
    /// otherwise below, kept on screen. The pen writes or changes the beta.
    private func callout(for position: GridPosition, text: String?, size: CGSize) -> some View {
        let g = PreviewGeometry(size: size, zoom: zoom, centre: centre)
        let hold = g.screenPoint(column: position.column, row: position.row)
        let gap = max(g.scale * 0.65, 9)
        let above = hold.y - gap - calloutHeight > PreviewGeometry.topInset
        let left = min(max(hold.x - Self.calloutWidth / 2, 4), size.width - Self.calloutWidth - 4)
        return HoldCallout(name: position.name, text: text) {
            editing = EditTarget(position: position)
        }
        .frame(width: Self.calloutWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { calloutHeight = $0 }
        .offset(x: left, y: above ? hold.y - gap - calloutHeight : hold.y + gap)
        .transition(.opacity)
    }

    /// Back and the beta pen, small, on the clock's line.
    private var topBar: some View {
        HStack(spacing: 4) {
            backButton
            betaToggle
        }
        .padding(.top, SessionView.Header.top)
        .padding(.leading, SessionView.Header.leading - 4)
        .ignoresSafeArea()
    }

    /// A small pen circle: shows or hides every note next to its hold.
    private var betaToggle: some View {
        Button {
            if beta.isEmpty {
                show("Tap a hold to add beta")
            } else {
                withAnimation(.snappy) { showAllBeta.toggle() }
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(showAllBeta && !beta.isEmpty ? .white : (beta.isEmpty ? Theme.secondaryText : Theme.white))
                .frame(width: 26, height: 26)
                .background(Circle().fill(showAllBeta && !beta.isEmpty ? Theme.blue : Theme.card))
                .frame(minHeight: SessionView.Header.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showAllBeta ? "Hide beta" : "Show beta")
        .accessibilityIdentifier("previewBeta")
    }

    /// Small text on the clock's line instead of the big round back button, so the
    /// board gets the room. Lines up with the problem name on Session.
    private var backButton: some View {
        Button {
            router.pop()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blue)
            .frame(minHeight: SessionView.Header.height)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("previewBack")
    }

    @ViewBuilder
    private var messageView: some View {
        if let message {
            Text(message.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.card))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity)
                .id(message.id)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Touches

    /// Pan, tap (a hold's callout; double-tap resets the zoom) and long press in one
    /// gesture, because SwiftUI's long press doesn't say where you pressed.
    private func touches(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let geometry = PreviewGeometry(size: size, zoom: zoom, centre: centre)
                if touch == nil {
                    let new = Touch(start: value.startLocation, centre: geometry.centre)
                    touch = new
                    Task {
                        try? await Task.sleep(for: Self.longPressDuration)
                        guard var current = touch, current.id == new.id, !current.moved else { return }
                        current.longPressed = true
                        touch = current
                        longPress(at: current.start, size: size)
                    }
                }
                guard var current = touch, !current.longPressed else { return }
                if !current.moved, hypot(value.translation.width, value.translation.height) > Self.moveSlop {
                    current.moved = true
                    touch = current
                }
                if current.moved {
                    let scale = geometry.scale
                    centre = geometry.clamped(CGPoint(x: current.centre.x - value.translation.width / scale,
                                                      y: current.centre.y - value.translation.height / scale))
                }
            }
            .onEnded { _ in
                let ended = touch
                touch = nil
                guard let ended, !ended.moved, !ended.longPressed else { return }
                if let lastTap, Date.now.timeIntervalSince(lastTap) < Self.doubleTapInterval {
                    self.lastTap = nil
                    withAnimation(.snappy) {
                        selected = nil
                        zoom = 1
                        centre = PreviewGeometry.boardCentre
                    }
                } else {
                    lastTap = .now
                    tap(at: ended.start, size: size)
                }
            }
    }

    /// Opens the callout for the problem hold under a tap. Tapping the same hold
    /// again, or anywhere that isn't one of the problem's holds, closes it.
    private func tap(at point: CGPoint, size: CGSize) {
        guard let problem else { return }
        let geometry = PreviewGeometry(size: size, zoom: zoom, centre: centre)
        let holds = problem.holds.compactMap { GridPosition($0.position) }
        let position = geometry.position(at: point, among: holds)
        withAnimation(.snappy(duration: 0.15)) {
            selected = position == selected ? nil : position
        }
    }

    private func longPress(at point: CGPoint, size: CGSize) {
        guard let problem else { return }
        let geometry = PreviewGeometry(size: size, zoom: zoom, centre: centre)
        let positions = problem.holds.compactMap { GridPosition($0.position) }
        guard let position = geometry.position(at: point, among: positions) else { return }
        switch model.markHighPoint(position, on: problem) {
        case .marked(let name): show("High point \(name)")
        case .cleared: show("High point cleared")
        case .sent: show("Sent!")
        case .startHold: show("Start holds can't be a high point")
        case .notInProblem: break
        }
    }

    private func show(_ text: String) {
        let new = Message(text: text)
        withAnimation(.snappy) { message = new }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if message?.id == new.id {
                withAnimation(.snappy) { message = nil }
            }
        }
    }

    // MARK: - Drawing

    private static func draw(_ problem: Problem, highPoint: String?, beta: [String: String], showAllBeta: Bool,
                             selected: GridPosition?, geometry g: PreviewGeometry, in context: inout GraphicsContext) {
        let images = HoldImages.shared
        let scale = g.scale
        let inProblem = Set(problem.holds.compactMap { GridPosition($0.position) })

        // Faint dots where the other holds are, so the problem's place on the board
        // reads. Only positions with a hold on this set (140 on the 2016 set).
        let bolted = images.info(for: problem.holdSet).map { Set($0.positions) }
        let dot = max(1, scale * 0.06)
        for column in 0..<GridPosition.columns {
            for row in 1...GridPosition.rows {
                guard let position = GridPosition(column: column, row: row), !inProblem.contains(position),
                      bolted?.contains(position.name) ?? true else { continue }
                let centre = g.screenPoint(column: column, row: row)
                context.fill(Path(ellipseIn: CGRect(x: centre.x - dot, y: centre.y - dot, width: dot * 2, height: dot * 2)),
                             with: .color(Color(white: 0.22)))
            }
        }

        // The problem's holds, then outlines on the start and finish holds.
        let tile = (images.info(for: problem.holdSet)?.tileInCells ?? 1.44) * scale
        for hold in problem.holds {
            guard let position = GridPosition(hold.position) else { continue }
            let centre = g.screenPoint(column: position.column, row: position.row)
            if let sprite = images.sprite(for: position, holdSet: problem.holdSet) {
                let image = Image(decorative: sprite, scale: 1).interpolation(.high)
                context.draw(image, in: CGRect(x: centre.x - tile / 2, y: centre.y - tile / 2, width: tile, height: tile))
            }
        }
        // Start and finish holds get an outline hugging the hold, in green or red,
        // and your high point one in gold. Other hand holds don't need one: with the
        // other holds hidden, nothing clutters them. Thin and constant in points, so
        // it stays crisp at every zoom.
        let info = images.info(for: problem.holdSet)
        let line = max(1.3, scale * 0.055)
        for hold in problem.holds where hold.role != .hand || hold.position == highPoint {
            guard let position = GridPosition(hold.position) else { continue }
            let grid = g.boardPoint(column: position.column, row: position.row)
            let path: Path
            if let outline = info?.outline(for: position) {
                path = PreviewGeometry.smoothPath(outline.map {
                    g.screenPoint(boardX: grid.x + $0.x, boardY: grid.y + $0.y)
                })
            } else {
                let centre = g.screenPoint(boardX: grid.x, boardY: grid.y)
                let r = scale * 0.5
                path = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
            }
            let colour = hold.position == highPoint ? Theme.gold : Theme.color(for: hold.role)
            context.stroke(path, with: .color(colour),
                           style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }

        // The tapped hold gets a white ring.
        if let selected {
            let centre = g.screenPoint(column: selected.column, row: selected.row)
            let r = max(scale * 0.62, 8)
            context.stroke(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)),
                           with: .color(Theme.white), lineWidth: 1.5)
        }
        drawBeta(beta, showAll: showAllBeta, selected: selected, g, in: &context)
        drawLabels(g, in: &context)
    }

    /// A small white mark at the top right of every hold with beta, and with
    /// "show all" on, each note in a small pill beside its hold.
    private static func drawBeta(_ beta: [String: String], showAll: Bool, selected: GridPosition?,
                                 _ g: PreviewGeometry, in context: inout GraphicsContext) {
        for (name, text) in beta.sorted(by: { $0.key < $1.key }) {
            guard let position = GridPosition(name) else { continue }
            let hold = g.screenPoint(column: position.column, row: position.row)
            let r = max(g.scale * 0.16, 3)
            let mark = CGPoint(x: hold.x + g.scale * 0.45, y: hold.y - g.scale * 0.45)
            let dot = Path(ellipseIn: CGRect(x: mark.x - r, y: mark.y - r, width: r * 2, height: r * 2))
            context.fill(dot, with: .color(Theme.white))
            context.stroke(dot, with: .color(Theme.background), lineWidth: 1)

            guard showAll, position != selected else { continue }
            let label = context.resolve(Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.white))
            let maxWidth: CGFloat = 84
            let size = label.measure(in: CGSize(width: maxWidth, height: 28))
            let width = size.width + 10
            let height = min(size.height, 28) + 4
            let gap = max(g.scale * 0.6, 7)
            // Right of the hold, or left if it would run off the screen.
            var x = hold.x + gap
            if x + width > g.size.width - 2 { x = hold.x - gap - width }
            let pill = CGRect(x: x, y: hold.y - height / 2, width: width, height: height)
            let shape = Path(roundedRect: pill, cornerRadius: 6)
            context.fill(shape, with: .color(Color(white: 0.16).opacity(0.94)))
            context.stroke(shape, with: .color(Theme.white.opacity(0.6)), lineWidth: 1)
            context.draw(label, in: pill.insetBy(dx: 5, dy: 2))
        }
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
    /// Space on the right and bottom so outlines on column K and row 1 fit.
    static let margin = 0.25
    static let boardWidth = Double(GridPosition.columns) + gutterLeft + margin
    static let boardHeight = Double(GridPosition.rows) + gutterTop + margin
    static let boardCentre = CGPoint(x: boardWidth / 2, y: boardHeight / 2)
    static let zoomRange: ClosedRange<Double> = 1...4
    /// Room left at the top for Back and the clock, in points.
    static let topInset: CGFloat = 36
    /// Room at the bottom, so row 1 sits clear of the screen's rounded corners.
    static let bottomInset: CGFloat = 8
    /// How far (in points) you can pan past each edge of the board, so holds in the
    /// corners can be moved clear of the screen's rounding.
    static let overscroll: CGFloat = 20

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
        CGRect(x: 0, y: Self.topInset, width: size.width,
               height: max(1, size.height - Self.topInset - Self.bottomInset))
    }

    var fitScale: CGFloat { min(viewport.width / Self.boardWidth, viewport.height / Self.boardHeight) }

    /// Points per grid cell.
    var scale: CGFloat { fitScale * zoom }

    func screenPoint(boardX x: CGFloat, boardY y: CGFloat) -> CGPoint {
        CGPoint(x: viewport.midX + (x - centre.x) * scale, y: viewport.midY + (y - centre.y) * scale)
    }

    func screenPoint(column: Int, row: Int) -> CGPoint {
        let point = boardPoint(column: column, row: row)
        return screenPoint(boardX: point.x, boardY: point.y)
    }

    /// A grid point in board units.
    func boardPoint(column: Int, row: Int) -> CGPoint {
        CGPoint(x: Self.gutterLeft + CGFloat(column) + 0.5, y: Self.gutterTop + CGFloat(GridPosition.rows - row) + 0.5)
    }

    /// The problem hold nearest a screen point, if it's within about a cell.
    func position(at point: CGPoint, among positions: [GridPosition]) -> GridPosition? {
        let board = CGPoint(x: centre.x + (point.x - viewport.midX) / scale,
                            y: centre.y + (point.y - viewport.midY) / scale)
        func distance(_ position: GridPosition) -> CGFloat {
            let grid = boardPoint(column: position.column, row: position.row)
            return hypot(grid.x - board.x, grid.y - board.y)
        }
        guard let nearest = positions.min(by: { distance($0) < distance($1) }), distance(nearest) < 0.75 else {
            return nil
        }
        return nearest
    }

    /// A closed, smooth curve through an outline's points: quadratic curves between
    /// the midpoints of each side, with the points as control points.
    static func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count >= 3 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(points[points.count - 1], points[0]))
        for i in points.indices {
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % points.count]), control: points[i])
        }
        path.closeSubpath()
        return path
    }

    /// Keeps the board on screen. Along an axis where it's bigger than the
    /// viewport you can pan until its edge meets the viewport's edge; where it fits,
    /// it stays centred. Either way you can go `overscroll` points further.
    func clamped(_ point: CGPoint) -> CGPoint {
        let over = Self.overscroll / scale
        func axis(_ value: CGFloat, board: CGFloat, half: CGFloat) -> CGFloat {
            let low = min(half, board / 2) - over
            let high = max(board - half, board / 2) + over
            return min(max(value, low), high)
        }
        return CGPoint(x: axis(point.x, board: Self.boardWidth, half: viewport.width / (2 * scale)),
                       y: axis(point.y, board: Self.boardHeight, half: viewport.height / (2 * scale)))
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
