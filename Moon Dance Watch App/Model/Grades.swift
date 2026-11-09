import Foundation

/// V grades and the Font grades MoonBoard uses for them.
/// Must match FONT_TO_V in tools/build_problems.py.
nonisolated enum Grades {
    /// Grades offered in the picker. The dataset starts at 6B (V4) on both 40°
    /// hold sets, so V0–V3 would always be empty.
    static let range = 4...14

    static let fontByV: [Int: [String]] = [
        0: ["4", "4+"],
        1: ["5"],
        2: ["5+"],
        3: ["6A", "6A+"],
        4: ["6B", "6B+"],
        5: ["6C", "6C+"],
        6: ["7A"],
        7: ["7A+"],
        8: ["7B", "7B+"],
        9: ["7C"],
        10: ["7C+"],
        11: ["8A"],
        12: ["8A+"],
        13: ["8B"],
        14: ["8B+"],
    ]

    static func vName(_ vGrade: Int) -> String { "V\(vGrade)" }

    /// "6C / 6C+" for V5.
    static func fontRange(_ vGrade: Int) -> String {
        (fontByV[vGrade] ?? []).joined(separator: " / ")
    }

    /// "V5 · 6C+"
    static func label(vGrade: Int, font: String) -> String { "\(vName(vGrade)) · \(font)" }

    static func vGrade(forFont font: String) -> Int? {
        fontByV.first { $0.value.contains(font) }?.key
    }
}
