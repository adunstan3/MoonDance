import SwiftData
import SwiftUI

/// Starred problems for the current hold set, newest first.
struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \Project.dateAdded, order: .reverse) private var projects: [Project]
    @Query private var logs: [LogEntry]

    var body: some View {
        let holdSet = settings.holdSet.rawValue
        let mine = projects.filter { $0.holdSet == holdSet }
        let problems = SessionModel.problems(ids: Set(mine.map(\.problemId)), context: context)
        let stats = LogStats(entries: logs, holdSet: holdSet)
        List {
            Text("\(settings.holdSet.label) · \(mine.count) project\(mine.count == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
            if mine.isEmpty {
                Label("Tap the star on a problem to make it a project.", systemImage: "star")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)
            }
            ForEach(mine, id: \.problemId) { project in
                if let problem = problems[project.problemId] {
                    Button {
                        session.show(problemID: problem.problemId, context: context, settings: settings)
                        router.showSession()
                    } label: {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(problem.name).font(.headline).lineLimit(2)
                                GradeLine(problem: problem)
                            }
                            Spacer(minLength: 2)
                            ProblemRowTrailing(stats: stats[problem.problemId], isProject: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Projects")
    }
}
