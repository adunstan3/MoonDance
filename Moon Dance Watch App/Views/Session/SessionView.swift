import SwiftData
import SwiftUI

/// Home: the hold grid, a side column, and Light it. The Digital Crown steps
/// through the problem list; tapping the name opens the list.
struct SessionView: View {
    @Environment(SessionModel.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
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
                SideColumn(problem: problem, stats: stats, isProject: isProject, position: session.positionText)
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

/// Grade, B badge, attempts or Sent, project star, list position.
private struct SideColumn: View {
    let problem: Problem
    let stats: ProblemStats
    let isProject: Bool
    let position: String

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
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 4)
            Label(isProject ? "Project" : "Star", systemImage: isProject ? "star.fill" : "star")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isProject ? Theme.white : Theme.secondaryText)
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
}
