import Foundation
import SwiftData
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct SnapshotTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func bundled() throws -> SnapshotLoader.Snapshot {
        let url = try #require(SnapshotLoader.bundledSnapshotURL())
        return try SnapshotLoader.decode(from: url)
    }

    @Test func bundledSnapshotHasBothHoldSets() throws {
        let snapshot = try bundled()
        for set in HoldSet.allCases {
            let problems = snapshot.problems.filter { $0.holdSet == set.rawValue }
            #expect(problems.count > 500, "too few \(set.rawValue) problems")
            #expect(problems.contains { $0.isBenchmark })
        }
        #expect(Set(snapshot.problems.map(\.id)).count == snapshot.problems.count)
    }

    @Test func bundledProblemsAreWellFormed() throws {
        for problem in try bundled().problems {
            #expect(!problem.holds.isEmpty)
            #expect(problem.holds.allSatisfy { GridPosition($0.position) != nil }, "\(problem.name)")
            #expect(problem.holds.contains { $0.role == .start }, "\(problem.name) has no start")
            #expect(problem.holds.contains { $0.role == .finish }, "\(problem.name) has no finish")
            #expect(Grades.vGrade(forFont: problem.fontGrade) == problem.vGrade, "\(problem.fontGrade)")
        }
    }

    @Test func extrasAreCappedAt300PerGrade() throws {
        let snapshot = try bundled()
        for set in HoldSet.allCases {
            for vGrade in [4, 5] {
                let extras = snapshot.problems.filter { $0.holdSet == set.rawValue && $0.vGrade == vGrade && !$0.isBenchmark }
                #expect(extras.count <= 300)
            }
            let otherExtras = snapshot.problems.filter { $0.holdSet == set.rawValue && ![4, 5].contains($0.vGrade) && !$0.isBenchmark }
            #expect(otherExtras.isEmpty)
        }
    }

    @Test func loadsOnceThenSkips() throws {
        let container = try Store.makeContainer(inMemory: true)
        let context = container.mainContext
        let defaults = freshDefaults()
        let url = SnapshotLoader.bundledSnapshotURL()

        #expect(try SnapshotLoader.loadIfNeeded(into: context, from: url, defaults: defaults))
        let count = try context.fetchCount(FetchDescriptor<Problem>())
        #expect(count == (try bundled().problems.count))

        #expect(try !SnapshotLoader.loadIfNeeded(into: context, from: url, defaults: defaults))
        #expect(try context.fetchCount(FetchDescriptor<Problem>()) == count)
    }

    @Test func newSnapshotReplacesProblemsButKeepsLogsAndProjects() throws {
        let container = try Store.makeContainer(inMemory: true)
        let context = container.mainContext
        let defaults = freshDefaults()
        try SnapshotLoader.loadIfNeeded(into: context, from: SnapshotLoader.bundledSnapshotURL(), defaults: defaults)

        context.insert(LogEntry(problemId: "abc", holdSet: "2024", isSend: false))
        context.insert(Project(problemId: "abc", holdSet: "2024"))
        try context.save()

        let json = """
        {"version":"test-2","source":"test","problems":[
          {"id":"abc","holdSet":"2024","name":"Renamed","setter":"me","fontGrade":"6C+","vGrade":5,
           "isBenchmark":true,"repeats":3,"holds":[{"position":"A5","role":"start"},{"position":"B18","role":"finish"}]}
        ]}
        """
        let url = FileManager.default.temporaryDirectory.appending(path: "snapshot-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try SnapshotLoader.loadIfNeeded(into: context, from: url, defaults: defaults))
        let problems = try context.fetch(FetchDescriptor<Problem>())
        #expect(problems.map(\.name) == ["Renamed"])
        #expect(try context.fetchCount(FetchDescriptor<LogEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
        #expect(defaults.string(forKey: SnapshotLoader.versionKey) == "test-2")
    }

    @Test func missingFileThrowsAndLeavesVersionUnset() throws {
        let container = try Store.makeContainer(inMemory: true)
        let defaults = freshDefaults()
        #expect(throws: SnapshotLoader.LoadError.self) {
            try SnapshotLoader.loadIfNeeded(into: container.mainContext, from: nil, defaults: defaults)
        }
        #expect(defaults.string(forKey: SnapshotLoader.versionKey) == nil)
    }

    @Test func gradeLabels() {
        #expect(Grades.label(vGrade: 5, font: "6C+") == "V5 · 6C+")
        #expect(Grades.fontRange(5) == "6C / 6C+")
        #expect(Grades.vGrade(forFont: "7A+") == 7)
        #expect(Grades.vGrade(forFont: "9A") == nil)
    }
}
