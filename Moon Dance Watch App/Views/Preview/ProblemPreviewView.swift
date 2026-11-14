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
/// Tap a hold (or any bolt) to flash its coordinates, such as "G13", above it.
/// "Beta" beside Back shows your notes over the board (or, with none yet, opens
/// the editor).
struct ProblemPreviewView: View {
    let problemID: String

    init(problemID: String) {
        self.problemID = problemID
        _betaNotes = Query(filter: #Predicate<BetaNote> { $0.problemId == problemID })
    }

    static let longPressDuration: Duration = .milliseconds(500)
    /// How far a finger can drift before a touch becomes a pan, in points.
    static let moveSlop: CGFloat = 6
    static let doubleTapInterval: TimeInterval = 0.35

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(AppModel.self) private var model
    @Query private var highPoints: [HighPoint]
    @Query private var betaNotes: [BetaNote]
    @State private var flash: Flash?
    @State private var showBeta = false
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

    /// A hold's coordinates, shown above it for a moment after a tap.
    struct Flash: Equatable {
        let id = UUID()
        let position: GridPosition
    }

    /// A short note after a long press ("High point G13", "Sent", …).
    private struct Message: Equatable {
        let id = UUID()
        let text: String
    }

    private var betaNote: BetaNote? {
        betaNotes.first { $0.holdSet == problem?.holdSet }
    }

    private var highPoint: String? {
        guard let problem else { return nil }
        return highPoints.first { $0.problemId == problem.problemId && $0.holdSet == problem.holdSet }?.position
    }

    var body: some View {
        // One size (the whole screen) for drawing, panning and zoom limits.
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, canvasSize in
                guard let problem else { return }
                let geometry = PreviewGeometry(size: canvasSize, zoom: zoom, centre: centre)
                Self.draw(problem, highPoint: highPoint, flash: flash?.position, geometry: geometry, in: &context)
            }
            .contentShape(Rectangle())
            .gesture(touches(size: size))
            .onChange(of: zoom) { centre = PreviewGeometry(size: size, zoom: zoom, centre: centre).centre }
            .accessibilityElement()
            .accessibilityIdentifier("problemPreview")
            .accessibilityLabel(problem.map { "Hold pictures for \($0.name)" } ?? "Problem preview")
            .accessibilityValue("Zoom \(Int((zoom * 100).rounded())) percent")
            .accessibilityHint("Turn the Digital Crown to zoom, drag to look around, double-tap to reset, "
                + "long-press a hold to mark your high point")
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { topBar }
        .overlay(alignment: .bottom) { betaPanel }
        .overlay(alignment: .bottom) { messageView }
        .toolbar(.hidden, for: .navigationBar)
        .focusable()
        .focused($crownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($zoom, from: PreviewGeometry.zoomRange.lowerBound,
                              through: PreviewGeometry.zoomRange.upperBound,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onAppear {
            problem = SessionModel.problem(id: problemID, context: context)
            crownFocused = true
            // Screenshots: -previewFlash G13 shows a coordinate; -previewBeta YES opens the notes.
            if let name = RuntimeEnvironment.debugValue("previewFlash"), let position = GridPosition(name) {
                flash = Flash(position: position)
            }
            if RuntimeEnvironment.debugValue("previewBeta") != nil { showBeta = true }
            // Screenshots: -previewZoom 3 -previewCentre 6,10 (board units).
            if let value = RuntimeEnvironment.debugValue("previewZoom"), let debugZoom = Double(value) {
                zoom = debugZoom
                let parts = RuntimeEnvironment.debugValue("previewCentre")?.split(separator: ",").compactMap { Double($0) }
                if let parts, parts.count == 2 { centre = CGPoint(x: parts[0], y: parts[1]) }
            }
        }
    }

    /// Back and Beta, small, on the clock's line.
    private var topBar: some View {
        HStack(spacing: 2) {
            backButton
            betaButton
        }
        .padding(.top, SessionView.Header.top)
        .padding(.leading, SessionView.Header.leading - 4)
        .ignoresSafeArea()
    }

    /// Shows or hides your notes over the board; with no notes yet, opens the editor.
    private var betaButton: some View {
        Button {
            if betaNote == nil {
                if let problem { router.push(.beta(problemID: problem.problemId, holdSet: problem.holdSet)) }
            } else {
                withAnimation(.snappy) { showBeta.toggle() }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "pencil")
                Text("Beta")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(betaNote == nil ? Theme.secondaryText : (showBeta ? Theme.blue : Theme.white))
            .frame(minHeight: SessionView.Header.height)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("previewBeta")
    }

    /// Your notes over the bottom of the board (up to five lines; tap them for the
    /// rest), with Edit and a close button.
    @ViewBuilder
    private var betaPanel: some View {
        if showBeta, let note = betaNote, let problem {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.text)
                    .font(.footnote)
                    .foregroundStyle(Theme.white)
                    .lineLimit(5)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.push(.beta(problemID: problem.problemId, holdSet: problem.holdSet))
                    }
                    .accessibilityIdentifier("previewBetaText")
                HStack {
                    Button {
                        router.push(.beta(problemID: problem.problemId, holdSet: problem.holdSet))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.blue)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        withAnimation(.snappy) { showBeta = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 30, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide beta")
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(0.96)))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
            .padding(.trailing, 8)
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

    /// Pan, tap (double-tap resets the zoom) and long press in one gesture, because
    /// SwiftUI's long press doesn't say where you pressed.
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
                        zoom = 1
                        centre = PreviewGeometry.boardCentre
                    }
                } else {
                    lastTap = .now
                    flashHold(at: ended.start, size: size)
                }
            }
    }

    /// Flashes the coordinates of the hold under a tap: a problem hold first, else
    /// any bolt on the hold set.
    private func flashHold(at point: CGPoint, size: CGSize) {
        guard let problem else { return }
        let geometry = PreviewGeometry(size: size, zoom: zoom, centre: centre)
        let holds = problem.holds.compactMap { GridPosition($0.position) }
        let bolts = (HoldImages.shared.info(for: problem.holdSet)?.positions ?? []).compactMap { GridPosition($0) }
        guard let position = geometry.position(at: point, among: holds) ?? geometry.position(at: point, among: bolts)
        else { return }
        let new = Flash(position: position)
        flash = new
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if flash?.id == new.id { flash = nil }
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

    private static func draw(_ problem: Problem, highPoint: String?, flash: GridPosition?,
                             geometry g: PreviewGeometry, in context: inout GraphicsContext) {
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

        drawLabels(g, in: &context)
        if let flash { drawFlash(flash, g, in: &context) }
    }

    /// The tapped hold's coordinates in a pill just above it (below it if that
    /// would run under the clock), kept on screen.
    private static func drawFlash(_ position: GridPosition, _ g: PreviewGeometry, in context: inout GraphicsContext) {
        let hold = g.screenPoint(column: position.column, row: position.row)
        let text = context.resolve(Text(position.name)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.white))
        let size = text.measure(in: CGSize(width: 200, height: 60))
        let width = size.width + 16
        let height = size.height + 6
        let gap = max(g.scale * 0.7, 10)
        var y = hold.y - gap - height
        if y < PreviewGeometry.topInset { y = hold.y + gap }
        let x = min(max(hold.x - width / 2, 4), g.size.width - width - 4)
        let pill = CGRect(x: x, y: y, width: width, height: height)
        let shape = Path(roundedRect: pill, cornerRadius: height / 2)
        context.fill(shape, with: .color(Color(white: 0.16)))
        context.stroke(shape, with: .color(Theme.white), lineWidth: 1.5)
        context.draw(text, at: CGPoint(x: pill.midX, y: pill.midY))
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
