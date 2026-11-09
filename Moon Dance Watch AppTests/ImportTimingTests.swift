import Foundation
import SwiftData
import Testing
@testable import Moon_Dance_Watch_App

/// The first-launch import runs before the app shows anything, so keep it quick.
@MainActor
struct ImportTimingTests {
    @Test func onDiskImportIsQuick() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "timing-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let schema = Schema(Store.models)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let snapshot = try SnapshotLoader.decode(from: #require(SnapshotLoader.bundledSnapshotURL()))
        let elapsed = try ContinuousClock().measure {
            try SnapshotLoader.replaceProblems(in: container.mainContext, with: snapshot)
        }
        // About 0.3 s in the simulator; the watch is slower, so leave plenty of room.
        #expect(elapsed < .seconds(3), "Import of \(snapshot.problems.count) problems took \(elapsed)")
    }
}
