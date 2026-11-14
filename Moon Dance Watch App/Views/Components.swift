import SwiftUI

/// The white "B" badge for benchmarks.
struct BenchmarkBadge: View {
    var body: some View {
        Text("B")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Theme.white, in: RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("Benchmark")
    }
}

/// "V5 · 6C+ [B]" as used in list rows.
struct GradeLine: View {
    let problem: Problem
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 4) {
            Text(problem.grade(settings.gradeScale))
                .foregroundStyle(Theme.secondaryText)
            if problem.isBenchmark {
                BenchmarkBadge()
            }
        }
        .font(.footnote)
    }
}

/// Green check for a sent problem.
struct SentCheck: View {
    var body: some View {
        Image(systemName: "checkmark.circle")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.green)
            .accessibilityLabel("Sent")
    }
}

/// "✎ ★ 7×" / "✓" trailing info for a problem row: a pen if it has beta.
struct ProblemRowTrailing: View {
    let stats: ProblemStats
    let isProject: Bool
    var hasBeta = false
    /// Projects list: always show the star.
    var showsStar = true

    var body: some View {
        HStack(spacing: 4) {
            if hasBeta {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.white)
                    .accessibilityLabel("Has beta")
            }
            if isProject && showsStar {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.white)
                    .accessibilityLabel("Project")
            }
            if stats.isSent {
                SentCheck()
            } else if stats.attempts > 0 {
                Text("\(stats.attempts)×")
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
                    .accessibilityLabel("\(stats.attempts) attempts")
            }
        }
    }
}

/// A rounded pill used for header chips ("2024 · 40°", "V5 ⌄").
struct Chip: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if !text.isEmpty {
                Text(text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.card, in: Capsule())
    }
}

/// Section header text in the design's style ("HOLD SET", "TODAY").
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
    }
}
