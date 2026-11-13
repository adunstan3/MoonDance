import SwiftData
import SwiftUI

/// Home: the hold grid, a side column, and Light it. The Digital Crown steps
/// through the problem list; tapping the name opens the list.
///
/// Logging on screen: tap the attempts count for +1 attempt, hold it for Sent,
/// tap the star to make it a project. Each log shows a banner with Undo.
struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(SessionModel.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(BannerModel.self) private var banner

    @State private var crown: Double = 0
    @FocusState private var crownFocused: Bool

    /// Layout of the custom header, which sits on the same line as the system clock.
    enum Header {
        static let top: CGFloat = 16
        static let height: CGFloat = 24
        static let leading: CGFloat = 16
        /// Room left for the clock at the top right.
        static let clockWidth: CGFloat = 62
    }

    /// True when the problem name takes two lines; the side column tightens up.
    @State private var nameWraps = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if let problem = session.current {
                    SessionProblemView(problem: problem, compact: nameWraps)
                } else {
                    emptyState.frame(maxHeight: .infinity)
                }
            }
            .overlay(alignment: .top) {
                if let current = banner.current {
                    BannerView(banner: current) { model.undoBanner() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .toolbar(.hidden, for: .navigationBar)
        .animation(.snappy, value: banner.current)
        .focusable()
        .focused($crownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($crown, from: 0, through: Double(max(session.problems.count - 1, 1)), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
            session.select(index: Int(value.rounded()), settings: settings)
        }
        .onChange(of: session.index, initial: true) { _, index in
            if Int(crown.rounded()) != index { crown = Double(index) }
        }
        .onChange(of: session.current?.problemId) { _, newID in
            // A banner's Undo belongs to the problem it was logged on.
            if let shown = banner.current?.problemID, shown != newID {
                banner.dismiss()
            }
        }
        .onAppear { crownFocused = true }
    }

    private var chevron: some View {
        Text(Image(systemName: "chevron.down"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.secondaryText)
    }

    /// The problem name on the clock's line; tapping it opens the problem list.
    /// The problem name across the top, on the clock's line. Long names wrap to a
    /// second line (then "…"), pushing the grid and side column down.
    private var header: some View {
        HStack(spacing: 0) {
            Button {
                router.push(.problemList)
            } label: {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(session.current?.name ?? "Problems")
                        .foregroundStyle(Theme.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    chevron
                }
                .font(.headline)
                .frame(minHeight: Header.height, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("problemName")
            .accessibilityHint("Opens the problem list")
            Spacer(minLength: Header.clockWidth)
        }
        .padding(.top, Header.top)
        .padding(.leading, Header.leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            nameWraps = height > Header.top + Header.height + 6
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.title2)
                .foregroundStyle(Theme.blue)
            Text("No \(Grades.bucketName(settings.lastGrade, scale: settings.gradeScale))\(settings.benchmarksOnly ? " benchmarks" : " problems") for \(settings.holdSet.label)")
                .multilineTextAlignment(.center)
            Button("Pick a grade") { router.push(.gradePicker) }
                .tint(Theme.blue)
        }
    }
}

/// The current problem's grid and side column. Its queries fetch only this
/// problem's log, star and high point, so stepping with the Crown doesn't
/// recount the whole log.
private struct SessionProblemView: View {
    let problem: Problem
    /// Tighter side column when the problem name takes two lines.
    let compact: Bool

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Query private var logs: [LogEntry]
    @Query private var projects: [Project]
    @Query private var highPoints: [HighPoint]

    init(problem: Problem, compact: Bool) {
        self.problem = problem
        self.compact = compact
        let id = problem.problemId
        let set = problem.holdSet
        _logs = Query(filter: #Predicate<LogEntry> { $0.problemId == id && $0.holdSet == set })
        _projects = Query(filter: #Predicate<Project> { $0.problemId == id && $0.holdSet == set })
        _highPoints = Query(filter: #Predicate<HighPoint> { $0.problemId == id && $0.holdSet == set })
    }

    var body: some View {
        let stats = LogStats(entries: logs)[problem.problemId]
        let isProject = !projects.isEmpty
        // The grid takes the full height on the left; everything else, Light it
        // included, is in the column on the right. A two-line name pushes both down
        // and the column tightens up.
        return HStack(alignment: .top, spacing: 10) {
            HoldGridView(holds: problem.holds, holdSet: problem.holdSet, highPoint: highPoints.first?.position)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.problemPreview(problem.problemId)) }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("holdGrid")
                .accessibilityHint("Tap for hold pictures. Turn the Digital Crown for the next problem")
            SideColumn(problem: problem, stats: stats, isProject: isProject, scale: settings.gradeScale,
                       compact: compact,
                       onAttempt: model.logAttempt, onSent: model.markSent, onUnsend: model.unsend,
                       onStar: model.toggleProject)
                .frame(width: SideColumn.width)
        }
        .padding(.top, 8)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.bottom, 12)
    }
}

/// "+1 attempt · 8 total   [Undo]" or "Sent   [Undo]".
struct BannerView: View {
    let banner: BannerModel.Banner
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if banner.kind == .sent {
                Image(systemName: "checkmark.circle")
            } else if banner.kind == .error {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            Text(banner.text)
                .font(.footnote.weight(.bold))
                .lineLimit(banner.kind == .error ? 2 : 1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            if banner.canUndo {
                Button(action: undo) {
                    Text("Undo")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(.black, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(color)
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: 38)
        .background(color.opacity(0.18), in: Capsule())
        .background(.black, in: Capsule())
        .overlay(Capsule().strokeBorder(color, lineWidth: 2))
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo", undo)
    }

    private var color: Color {
        switch banner.kind {
        case .attempt, .info: Theme.blue
        case .sent: Theme.green
        case .error: Theme.red
        }
    }
}

/// Grade with the B badge, attempts or Sent, project star, and Light it / Clear.
private struct SideColumn: View {
    static let width: CGFloat = 74

    let problem: Problem
    let stats: ProblemStats
    let isProject: Bool
    let scale: GradeScale
    /// Tighter spacing when the problem name takes two lines.
    let compact: Bool
    let onAttempt: () -> Void
    let onSent: () -> Void
    let onUnsend: () -> Void
    let onStar: () -> Void

    var body: some View {
        // Grade, tries and star sit together at the top; Light it is raised and
        // pulled in from the screen's rounded bottom-right corner.
        VStack(alignment: .leading, spacing: compact ? 1 : 6) {
            HStack(alignment: .center, spacing: 5) {
                Text(problem.grade(scale))
                    .font(.system(size: compact ? 26 : 30, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if problem.isBenchmark { BenchmarkBadge() }
            }
            attempts
            HStack(spacing: 5) {
                Image(systemName: isProject ? "star.fill" : "star")
                    .font(.system(size: 21, weight: .semibold))
                Text("Star")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
                .foregroundStyle(isProject ? Theme.white : Theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: compact ? 26 : 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onStar)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isProject ? "Project. Tap to unstar" : "Star as a project")
                .accessibilityAction { onStar() }
            Spacer(minLength: 0)
            LightControls(problem: problem)
                .padding(.trailing, 6)
                .padding(.bottom, compact ? 8 : 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Tap: +1 attempt. Hold: Sent, or, if already sent, Unsend (the latest send becomes an attempt).
    private var attempts: some View {
        VStack(alignment: .leading, spacing: 0) {
            if stats.isSent {
                Label("Sent", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(Theme.green)
                Text("\(stats.attempts) \(stats.attempts == 1 ? "try" : "tries")")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(stats.attempts)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(stats.attempts == 1 ? "try" : "tries")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 32 : 40, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in stats.isSent ? onUnsend() : onSent() }
                .exclusively(before: TapGesture().onEnded { onAttempt() })
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(stats.isSent
            ? "Tap for one more attempt. Touch and hold to undo the latest send."
            : "Tap for one more attempt. Touch and hold to mark sent.")
        .accessibilityAction(named: "Add attempt") { onAttempt() }
        .accessibilityAction(named: stats.isSent ? "Unsend" : "Mark sent") { stats.isSent ? onUnsend() : onSent() }
    }
}
