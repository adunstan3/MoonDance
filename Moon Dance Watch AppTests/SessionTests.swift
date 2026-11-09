import Foundation
import SwiftData
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct SessionTests {
    let container: ModelContainer
    let settings: AppSettings

    init() throws {
        container = try Store.makeContainer(inMemory: true)
        let name = "session-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        settings = AppSettings(defaults: defaults)
        let context = container.mainContext
        func add(_ id: String, _ set: String, _ v: Int, bench: Bool, repeats: Int) {
            context.insert(Problem(problemId: id, holdSet: set, name: id, setter: "", fontGrade: "6C",
                                   vGrade: v, isBenchmark: bench, repeats: repeats,
                                   holds: [Hold(position: "A5", role: .start), Hold(position: "A18", role: .finish)]))
        }
        add("a", "2024", 5, bench: true, repeats: 50)
        add("b", "2024", 5, bench: false, repeats: 90)
        add("c", "2024", 5, bench: false, repeats: 10)
        add("d", "2024", 6, bench: true, repeats: 5)
        add("e", "2016", 5, bench: true, repeats: 70)
        try context.save()
    }

    @Test func listFollowsHoldSetGradeAndBenchmarks() {
        let session = SessionModel()
        settings.holdSet = .mb2024
        settings.lastGrade = 5
        session.reload(context: container.mainContext, settings: settings)
        #expect(session.problems.map(\.problemId) == ["b", "a", "c"])  // most repeated first

        settings.benchmarksOnly = true
        session.reload(context: container.mainContext, settings: settings)
        #expect(session.problems.map(\.problemId) == ["a"])

        settings.benchmarksOnly = false
        settings.holdSet = .mb2016
        session.reload(context: container.mainContext, settings: settings)
        #expect(session.problems.map(\.problemId) == ["e"])
    }

    @Test func crownSteppingIsClamped() {
        let session = SessionModel()
        settings.lastGrade = 5
        session.reload(context: container.mainContext, settings: settings)
        #expect(session.index == 0)
        #expect(session.positionText == "1 / 3")
        session.step(by: 1, settings: settings)
        #expect(session.current?.problemId == "a")
        session.step(by: 5, settings: settings)
        #expect(session.index == 2)
        session.step(by: -9, settings: settings)
        #expect(session.index == 0)
    }

    @Test func reloadKeepsTheCurrentProblem() {
        let session = SessionModel()
        settings.lastGrade = 5
        session.reload(context: container.mainContext, settings: settings)
        session.select(index: 2, settings: settings)
        session.reload(context: container.mainContext, settings: settings)
        #expect(session.current?.problemId == "c")

        // A fresh model picks up the last problem viewed (survives relaunch).
        let relaunched = SessionModel()
        relaunched.reload(context: container.mainContext, settings: settings)
        #expect(relaunched.current?.problemId == "c")
    }

    @Test func showSwitchesGradeAndHoldSet() {
        let session = SessionModel()
        settings.lastGrade = 5
        settings.benchmarksOnly = true
        session.reload(context: container.mainContext, settings: settings)

        session.show(problemID: "d", context: container.mainContext, settings: settings)
        #expect(settings.lastGrade == 6)
        #expect(session.current?.problemId == "d")

        session.show(problemID: "e", context: container.mainContext, settings: settings)
        #expect(settings.holdSet == .mb2016)
        #expect(session.current?.problemId == "e")
    }

    @Test func emptyGradeHasNoCurrentProblem() {
        let session = SessionModel()
        settings.lastGrade = 2
        session.reload(context: container.mainContext, settings: settings)
        #expect(session.current == nil)
        #expect(session.positionText == "0 / 0")
        session.step(by: 1, settings: settings)
        #expect(session.index == 0)
    }
}

@MainActor
struct LightControlsTests {
    @Test func displayFollowsBoardStatus() {
        typealias D = LightControls.Display
        #expect(LightControls.display(status: .idle, lastJob: nil, isThisProblem: true) == D.ready)
        #expect(LightControls.display(status: .connecting, lastJob: .light, isThisProblem: true) == D.working("Connecting…"))
        #expect(LightControls.display(status: .sending, lastJob: .clear, isThisProblem: false) == D.working("Clearing…"))
        #expect(LightControls.display(status: .lit, lastJob: .light, isThisProblem: true) == D.lit)
        #expect(LightControls.display(status: .lit, lastJob: .light, isThisProblem: false) == D.ready)
        #expect(LightControls.display(status: .failed(.disconnected), lastJob: .light, isThisProblem: true) == D.failed)
        #expect(LightControls.display(status: .cleared, lastJob: .clear, isThisProblem: true) == D.ready)
    }
}

struct LogStatsTests {
    @Test func countsAttemptsAndSends() {
        let items = [
            LogStats.Item(problemId: "a", holdSet: "2024", isSend: false),
            LogStats.Item(problemId: "a", holdSet: "2024", isSend: false),
            LogStats.Item(problemId: "a", holdSet: "2024", isSend: true),
            LogStats.Item(problemId: "b", holdSet: "2016", isSend: true),
        ]
        let stats = LogStats(items: items, holdSet: "2024")
        #expect(stats["a"] == ProblemStats(attempts: 3, sends: 1))
        #expect(stats["a"].isSent)
        #expect(stats["b"] == ProblemStats())
        #expect(LogStats(items: items)["b"].attempts == 1)
    }
}

struct GridLayoutTests {
    @Test func rowEighteenIsAtTheTop() {
        let layout = GridLayout(size: CGSize(width: 110, height: 180))
        #expect(layout.cell == 10)
        #expect(layout.center(column: 0, row: 18) == CGPoint(x: 5, y: 5))
        #expect(layout.center(column: 10, row: 1) == CGPoint(x: 105, y: 175))
    }

    @Test func gridFillsATallerSpace() {
        // Rows spread over the full height; rings stay sized by the narrower cell.
        let layout = GridLayout(size: CGSize(width: 110, height: 216))
        #expect(layout.cellHeight == 12)
        #expect(layout.cell == 10)
        #expect(layout.center(column: 0, row: 1) == CGPoint(x: 5, y: 210))
    }
}
