import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct HighPointTests {
    let model: AppModel
    let problem: Problem
    let other: Problem

    init() throws {
        let name = "highpoint-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let container = try Store.makeContainer(inMemory: true)
        let holds = [Hold(position: "D5", role: .start), Hold(position: "E9", role: .hand),
                     Hold(position: "G13", role: .hand), Hold(position: "F18", role: .finish)]
        problem = Problem(problemId: "p1", holdSet: "2024", name: "p1", setter: "", fontGrade: "6C+", vGrade: 5,
                          isBenchmark: false, repeats: 5, holds: holds)
        other = Problem(problemId: "p2", holdSet: "2024", name: "p2", setter: "", fontGrade: "6C+", vGrade: 5,
                        isBenchmark: false, repeats: 4, holds: holds)
        container.mainContext.insert(problem)
        container.mainContext.insert(other)
        try container.mainContext.save()
        model = AppModel(settings: AppSettings(defaults: defaults), container: container)
        model.session.reload(context: model.context, settings: model.settings)
    }

    private func highPoint(_ problem: Problem) -> String? { Logbook.highPoint(for: problem, in: model.context) }
    private func stats(_ problem: Problem) -> ProblemStats { Logbook.stats(for: problem, in: model.context) }

    @Test func handHoldBecomesTheOneHighPoint() {
        #expect(model.markHighPoint(GridPosition("E9")!, on: problem) == .marked("E9"))
        #expect(highPoint(problem) == "E9")
        // Marking another replaces it: there's only ever one.
        #expect(model.markHighPoint(GridPosition("G13")!, on: problem) == .marked("G13"))
        #expect(highPoint(problem) == "G13")
        #expect(try! model.context.fetchCount(FetchDescriptor<HighPoint>()) == 1)
        // Other problems have their own.
        #expect(highPoint(other) == nil)
        #expect(stats(problem) == ProblemStats(), "a high point isn't a logged attempt")
    }

    @Test func markingTheSameHoldAgainClearsIt() {
        model.markHighPoint(GridPosition("E9")!, on: problem)
        #expect(model.markHighPoint(GridPosition("E9")!, on: problem) == .cleared)
        #expect(highPoint(problem) == nil)
    }

    @Test func startHoldsCantBeAHighPoint() {
        model.markHighPoint(GridPosition("E9")!, on: problem)
        #expect(model.markHighPoint(GridPosition("D5")!, on: problem) == .startHold)
        #expect(highPoint(problem) == "E9", "the old high point stays")
    }

    @Test func finishHoldLogsASend() {
        #expect(model.markHighPoint(GridPosition("F18")!, on: problem) == .sent)
        #expect(stats(problem) == ProblemStats(attempts: 1, sends: 1))
        #expect(highPoint(problem) == nil)
        #expect(model.banner.current?.kind == .sent)
        #expect(model.banner.current?.problemID == "p1")
    }

    @Test func positionsOffTheProblemAreIgnored() {
        #expect(model.markHighPoint(GridPosition("A1")!, on: problem) == .notInProblem)
        #expect(highPoint(problem) == nil)
    }

    @Test func longPressFindsTheNearestProblemHold() {
        let g = PreviewGeometry(size: CGSize(width: 205, height: 251), zoom: 2, centre: CGPoint(x: 6, y: 10))
        let holds = ["E9", "G13", "D5"].map { GridPosition($0)! }
        let e9 = g.screenPoint(column: 4, row: 9)
        #expect(g.position(at: e9, among: holds) == GridPosition("E9"))
        // A little off the bolt (holds aren't always centred) still counts.
        #expect(g.position(at: CGPoint(x: e9.x + g.scale * 0.4, y: e9.y - g.scale * 0.3), among: holds)
            == GridPosition("E9"))
        // Empty board between holds doesn't.
        let empty = g.screenPoint(column: 8, row: 9)
        #expect(g.position(at: empty, among: holds) == nil)
    }
}
