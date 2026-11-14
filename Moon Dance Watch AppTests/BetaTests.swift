import Foundation
import SwiftData
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct BetaTests {
    let context: ModelContext
    let container: ModelContainer

    init() throws {
        container = try Store.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func beta(_ holdSet: String = "2024") -> [String: String] {
        Logbook.beta(problemId: "p1", holdSet: holdSet, in: context)
    }

    @Test func betaIsPinnedToHolds() throws {
        #expect(beta().isEmpty)
        Logbook.setBeta("  heel hook  ", problemId: "p1", holdSet: "2024", position: "E9", in: context)
        Logbook.setBeta("match", problemId: "p1", holdSet: "2024", position: "G13", in: context)
        #expect(beta() == ["E9": "heel hook", "G13": "match"])
        // Editing a hold's beta replaces it.
        Logbook.setBeta("toe hook", problemId: "p1", holdSet: "2024", position: "E9", in: context)
        #expect(beta()["E9"] == "toe hook")
        #expect(try context.fetchCount(FetchDescriptor<BetaNote>()) == 2)
        // Blank text removes just that hold's beta.
        Logbook.setBeta("  ", problemId: "p1", holdSet: "2024", position: "E9", in: context)
        #expect(beta() == ["G13": "match"])
    }

    @Test func betaIsSeparatePerHoldSet() {
        Logbook.setBeta("2024 beta", problemId: "p1", holdSet: "2024", position: "E9", in: context)
        #expect(beta("2016").isEmpty)
    }
}

@MainActor
struct HighPointHistoryTests {
    @Test func markingRecordsHistoryButClearingDoesNot() throws {
        let container = try Store.makeContainer(inMemory: true)
        let context = container.mainContext
        let problem = Problem(problemId: "p1", holdSet: "2024", name: "p1", setter: "", fontGrade: "6C+", vGrade: 5,
                              isBenchmark: false, repeats: 1, holds: [])
        context.insert(problem)
        Logbook.setHighPoint("G13", for: problem, in: context)
        Logbook.setHighPoint("H15", for: problem, in: context)
        Logbook.setHighPoint(nil, for: problem, in: context)
        let marks = try context.fetch(FetchDescriptor<HighPointMark>(sortBy: [SortDescriptor(\.date)]))
        #expect(marks.map(\.position) == ["G13", "H15"])
        #expect(Logbook.highPoint(for: problem, in: context) == nil)
        let today = Logbook.highPointMarks(problemId: "p1", holdSet: "2024", on: .now, in: context)
        #expect(today.count == 2)
    }

    @Test func historyShowsTheDaysLatestHighPointWithoutCountingAnAttempt() {
        let now = Date.now
        let items = [
            History.Item(problemId: "a", date: now.addingTimeInterval(-120), isSend: false),
            History.Item(problemId: "a", date: now.addingTimeInterval(-60), isSend: false, highPoint: "G13"),
            History.Item(problemId: "a", date: now, isSend: false, highPoint: "H15"),
            History.Item(problemId: "b", date: now, isSend: false, highPoint: "C9"),
        ]
        let day = try! #require(History.days(from: items).first)
        let a = try! #require(day.problems.first { $0.problemId == "a" })
        #expect(a.attempts == 1)
        #expect(a.highPoint == "H15")
        // A high point alone still puts the problem in that day.
        let b = try! #require(day.problems.first { $0.problemId == "b" })
        #expect(b.attempts == 0)
        #expect(b.highPoint == "C9")
        #expect(day.attempts == 1)
    }
}
