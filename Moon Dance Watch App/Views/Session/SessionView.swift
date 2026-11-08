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
    @Query private var logs: [LogEntry]
    @Query private var projects: [Project]

    @State private var crown: Double = 0
    @FocusState private var crownFocused: Bool

    var body: some View {
        Group {
            if let problem = session.current {
                content(for: problem)
            } else {
                emptyState
            }
        }
        .overlay(alignment: .top) {
            if let current = banner.current {
                BannerView(banner: current) { model.undoBanner() }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: banner.current)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                nameButton
            }
        }
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

    private var nameButton: some View {
        Button {
            router.push(.problemList)
        } label: {
            HStack(spacing: 3) {
                Text(session.current?.name ?? "Problems")
                    .lineLimit(1)
                    .foregroundStyle(Theme.white)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .font(.headline)
            .textCase(nil)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the problem list")
    }

    private func content(for problem: Problem) -> some View {
        let stats = LogStats(entries: logs, holdSet: problem.holdSet)[problem.problemId]
        let isProject = projects.contains { $0.problemId == problem.problemId && $0.holdSet == problem.holdSet }
        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                HoldGridView(holds: problem.holds)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .layoutPriority(1)
                SideColumn(problem: problem, stats: stats, isProject: isProject, position: session.positionText,
                           onAttempt: model.logAttempt, onSent: model.markSent, onStar: model.toggleProject)
            }
            LightControls(problem: problem)
        }
        .padding(.horizontal, 2)
        .ignoresSafeArea(edges: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.title2)
                .foregroundStyle(Theme.blue)
            Text("No \(Grades.vName(settings.lastGrade))\(settings.benchmarksOnly ? " benchmarks" : " problems") for \(settings.holdSet.label)")
                .multilineTextAlignment(.center)
            Button("Pick a grade") { router.push(.gradePicker) }
                .tint(Theme.blue)
        }
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
            }
            Text(banner.text)
                .font(.footnote.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            if banner.entryID != nil {
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
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo", undo)
    }

    private var color: Color {
        switch banner.kind {
        case .attempt, .info: Theme.blue
        case .sent: Theme.green
        }
    }
}

/// Grade, B badge, attempts or Sent, project star, list position.
private struct SideColumn: View {
    let problem: Problem
    let stats: ProblemStats
    let isProject: Bool
    let position: String
    let onAttempt: () -> Void
    let onSent: () -> Void
    let onStar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Grades.vName(problem.vGrade))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text(problem.fontGrade)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                if problem.isBenchmark { BenchmarkBadge() }
            }
            Spacer(minLength: 4)
            attempts
            Spacer(minLength: 4)
            Label(isProject ? "Project" : "Star", systemImage: isProject ? "star.fill" : "star")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isProject ? Theme.white : Theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onStar)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isProject ? "Project. Tap to unstar" : "Star as a project")
                .accessibilityAction { onStar() }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                Text(position)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.secondaryText)
            .accessibilityLabel("Problem \(position). Turn the Digital Crown for the next one.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Tap: +1 attempt. Hold: Sent.
    private var attempts: some View {
        VStack(alignment: .leading, spacing: 0) {
            if stats.isSent {
                Label("Sent", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(Theme.green)
                Text("\(stats.attempts) attempt\(stats.attempts == 1 ? "" : "s")")
                    .font(.caption2)
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
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in onSent() }
                .exclusively(before: TapGesture().onEnded { onAttempt() })
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap for one more attempt. Touch and hold to mark sent.")
        .accessibilityAction(named: "Add attempt") { onAttempt() }
        .accessibilityAction(named: "Mark sent") { onSent() }
    }
}
