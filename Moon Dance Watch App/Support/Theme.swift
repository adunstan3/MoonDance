import SwiftUI

/// The board's LED colors plus white on near-black (CLAUDE.md, Look).
enum Theme {
    /// Start holds, Sent, success.
    static let green = Color(red: 0.20, green: 0.80, blue: 0.35)
    /// Hand holds, main actions, links.
    static let blue = Color(red: 0.24, green: 0.56, blue: 1.0)
    /// Finish holds, Clear, destructive actions.
    static let red = Color(red: 1.0, green: 0.30, blue: 0.27)
    /// Project stars, benchmark badge.
    static let white = Color.white
    /// Your high point on a problem.
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.22)
    /// Idle connection dot and empty grid dots.
    static let idle = Color(white: 0.45)
    static let background = Color(white: 0.02)
    static let card = Color(white: 0.11)
    static let secondaryText = Color(white: 0.62)

    static func color(for role: HoldRole) -> Color {
        switch role {
        case .start: green
        case .hand: blue
        case .finish: red
        }
    }
}
