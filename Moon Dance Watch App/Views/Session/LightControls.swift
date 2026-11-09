import SwiftUI

/// Bottom of the Session side column: a status line (dot + word, so it reads in
/// glare) over one button that is Light it, then Clear once the problem is lit.
struct LightControls: View {
    let problem: Problem

    @Environment(AppModel.self) private var model
    @Environment(BoardManager.self) private var board
    @Environment(SessionModel.self) private var session

    enum Display: Equatable {
        case ready
        case working(String)
        case lit
        case failed
    }

    /// Height of full-width buttons elsewhere (Use this board, Export).
    static let height: CGFloat = 42
    /// The Session button.
    static let buttonHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusLine
            button
        }
    }

    /// Gray idle (hidden), blue connecting, green lit, red failed.
    @ViewBuilder
    private var statusLine: some View {
        let (color, text): (Color, String) = switch display {
        case .ready: (Theme.idle, "Ready")
        case .working(let text): (Theme.blue, text)
        case .lit: (Theme.green, "Lit")
        case .failed: (Theme.red, "Failed")
        }
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(color)
        .opacity(display == .ready ? 0 : 1)
        .accessibilityHidden(display == .ready)
    }

    @ViewBuilder
    private var button: some View {
        switch display {
        case .ready:
            SessionButton(title: "Light it", style: .filled(Theme.blue)) {
                model.lightCurrent()
            }
        case .working:
            HStack {
                ProgressView()
                    .tint(Theme.blue)
            }
            .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
            .overlay(Capsule().strokeBorder(Theme.blue, lineWidth: 2))
            .accessibilityLabel("Working")
        case .lit:
            SessionButton(title: "Clear", style: .text(Theme.red)) {
                model.clearBoard()
            }
            .accessibilityLabel("Clear board")
        case .failed:
            SessionButton(title: "Retry", style: .filled(Theme.blue)) {
                model.lightCurrent()
            }
            .accessibilityLabel("Light it failed. Retry")
        }
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

/// The capsule button in the Session side column.
private struct SessionButton: View {
    enum Style {
        case filled(Color)
        case text(Color)
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            .font(.footnote.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: LightControls.buttonHeight)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .filled: .white
        case .text(let color): color
        }
    }

    private var background: Color {
        switch style {
        case .filled(let color): color
        case .text: Theme.card
        }
    }
}
