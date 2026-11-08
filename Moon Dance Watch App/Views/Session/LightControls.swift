import SwiftUI

/// The bottom of Session: Light it, or the Lit / connecting / failed state with Clear.
struct LightControls: View {
    let problem: Problem

    @Environment(BoardManager.self) private var board
    @Environment(SessionModel.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router

    enum Display: Equatable {
        case ready
        case working(String)
        case lit
        case failed
    }

    static let height: CGFloat = 42

    var body: some View {
        switch display {
        case .ready:
            Button(action: light) {
                Label("Light it", systemImage: "lightbulb")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Self.height)
                    .background(Theme.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        case .working(let text):
            StatusCapsule(color: Theme.blue, text: text)
                .accessibilityLabel(text)
        case .lit:
            HStack(spacing: 6) {
                StatusCapsule(color: Theme.green, text: "Lit")
                    .accessibilityLabel("Lit on the board")
                clearButton
                    .frame(maxWidth: 70)
            }
        case .failed:
            HStack(spacing: 6) {
                Button(action: light) {
                    StatusCapsule(color: Theme.red, text: "Retry")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Light it failed. Retry")
                clearButton
                    .frame(maxWidth: 70)
            }
        }
    }

    private var clearButton: some View {
        Button {
            board.clearBoard()
            session.litProblemID = nil
        } label: {
            Text("Clear")
                .font(.headline)
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity, minHeight: Self.height)
                .background(Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear board")
    }

    private func light() {
        guard settings.hasSavedBoard else {
            // First Light it: find and save the box, then light this problem.
            session.pendingLight = SessionModel.PendingLight(problemID: problem.problemId, holds: problem.holds)
            router.push(.findBoard)
            return
        }
        session.litProblemID = problem.problemId
        board.light(problem.holds)
    }

    /// What to show, from the board's status and which problem was lit last.
    var display: Display {
        Self.display(status: board.status, lastJob: board.lastJob,
                     isThisProblem: session.litProblemID == problem.problemId)
    }

    static func display(status: BoardManager.Status, lastJob: BoardManager.JobKind?,
                                    isThisProblem: Bool) -> Display {
        switch status {
        case .connecting:
            return .working(lastJob == .clear ? "Clearing…" : "Connecting…")
        case .sending:
            return .working(lastJob == .clear ? "Clearing…" : "Sending…")
        case .lit:
            return isThisProblem ? .lit : .ready
        case .failed:
            return isThisProblem ? .failed : .ready
        case .idle, .cleared:
            return .ready
        }
    }
}

/// An outlined capsule with a status dot: "● Lit", "● Connecting…".
struct StatusCapsule: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).font(.headline)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: LightControls.height)
        .overlay(Capsule().strokeBorder(color, lineWidth: 2.5))
        .contentShape(Capsule())
    }
}
