import SwiftData
import SwiftUI

/// The list for the current hold set and grade. Tapping a row opens it in Session.
struct ProblemListView: View {
    @Environment(SessionModel.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Query private var logs: [LogEntry]
    @Query private var projects: [Project]
    @Query private var betaNotes: [BetaNote]

    var body: some View {
        let holdSet = settings.holdSet.rawValue
        let stats = LogStats(entries: logs, holdSet: holdSet)
        let projectIDs = Set(projects.filter { $0.holdSet == holdSet }.map(\.problemId))
        let betaIDs = Set(betaNotes.filter { $0.holdSet == holdSet }.map(\.problemId))
        ScrollViewReader { proxy in
            List {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
                if session.problems.isEmpty {
                    Text("No problems here. Try another grade\(settings.benchmarksOnly ? " or turn off Benchmarks only" : "").")
                        .foregroundStyle(Theme.secondaryText)
                        .listRowBackground(Color.clear)
                }
                ForEach(Array(session.problems.enumerated()), id: \.element.problemId) { index, problem in
                    let isCurrent = index == session.index
                    Button {
                        session.select(index: index, settings: settings)
                        router.pop()
                    } label: {
                        ProblemRow(problem: problem, stats: stats[problem.problemId],
                                   isProject: projectIDs.contains(problem.problemId),
                                   hasBeta: betaIDs.contains(problem.problemId))
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.card)
                            .strokeBorder(isCurrent ? Theme.blue : .clear, lineWidth: 2)
                    )
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    .id(problem.problemId)
                }
            }
            .onAppear {
                if let id = session.current?.problemId {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .navigationTitle("Problems")
    }

    /// Opens a random problem from this list in Session.
    private func pickRandom() {
        session.selectRandom(settings: settings)
        router.pop()
    }

    /// Hold set and grade chips. Each is its own tap target (one List row = one
    /// tap target on watchOS, so these use tap gestures, not buttons).
    private var header: some View {
        HStack(spacing: 6) {
            Chip(text: settings.holdSet.label)
                .contentShape(Capsule())
                .onTapGesture { router.push(.settings) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Hold set \(settings.holdSet.label). Opens Settings")
                .accessibilityAction { router.push(.settings) }
            Chip(text: Grades.bucketName(settings.lastGrade, scale: settings.gradeScale)
                    + (settings.benchmarksOnly ? " · B" : ""),
                 systemImage: "chevron.down")
                .contentShape(Capsule())
                .onTapGesture { router.push(.gradePicker) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Grade \(Grades.bucketName(settings.lastGrade, scale: settings.gradeScale)). Opens the grade picker")
                .accessibilityAction { router.push(.gradePicker) }
            Spacer(minLength: 0)
            if session.problems.count > 1 {
                Chip(text: "", systemImage: "dice")
                    .contentShape(Capsule())
                    .onTapGesture(perform: pickRandom)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Random problem")
                    .accessibilityIdentifier("randomProblem")
                    .accessibilityAction { pickRandom() }
            }
        }
    }
}

struct ProblemRow: View {
    let problem: Problem
    let stats: ProblemStats
    let isProject: Bool
    var hasBeta = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(problem.name)
                    .font(.headline)
                    .lineLimit(2)
                GradeLine(problem: problem)
            }
            Spacer(minLength: 2)
            ProblemRowTrailing(stats: stats, isProject: isProject, hasBeta: hasBeta)
        }
        .padding(.vertical, 4)
    }
}
