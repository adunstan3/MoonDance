import Foundation
import SwiftData

/// Loads the bundled Problems.json into SwiftData on first launch, and again
/// whenever a new snapshot ships (its `version` changes). Logs and projects are
/// separate models and are never touched.
enum SnapshotLoader {
    static let versionKey = "problemSnapshotVersion"

    struct Snapshot: Decodable {
        let version: String
        let source: String
        let problems: [Record]
    }

    struct Record: Decodable {
        let id: String
        let holdSet: String
        let name: String
        let setter: String
        let fontGrade: String
        let vGrade: Int
        let isBenchmark: Bool
        let repeats: Int
        let holds: [Hold]
    }

    enum LoadError: LocalizedError {
        case missingFile

        var errorDescription: String? { "Problems.json is missing from the app" }
    }

    static func bundledSnapshotURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "Problems", withExtension: "json")
    }

    static func decode(from url: URL) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
    }

    /// The snapshot's version, read from the first few hundred bytes instead of
    /// parsing the whole 1 MB file (tools/build_problems.py writes "version" first).
    /// Nil if it isn't there, and the caller falls back to a full decode.
    nonisolated static func peekVersion(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 512) else { return nil }
        let head = String(decoding: data, as: UTF8.self)
        // Only trust a "version" that comes before the problem list starts.
        let beforeProblems = head.components(separatedBy: "\"problems\"").first ?? head
        guard let match = beforeProblems.firstMatch(of: /"version"\s*:\s*"([^"]*)"/) else { return nil }
        return String(match.1)
    }

    /// Loads the snapshot if the store doesn't already hold this version.
    /// Returns true if problems were (re)loaded. On failure the version isn't saved,
    /// so the next launch tries again. Usually only the file's first bytes are read.
    @discardableResult
    static func loadIfNeeded(into context: ModelContext, from url: URL?, defaults: UserDefaults = .standard) throws -> Bool {
        guard let url else { throw LoadError.missingFile }
        let existing = try context.fetchCount(FetchDescriptor<Problem>())
        let stored = defaults.string(forKey: versionKey)
        if existing > 0, let stored, stored == peekVersion(at: url) {
            return false
        }
        let snapshot = try decode(from: url)
        if stored == snapshot.version && existing > 0 {
            return false
        }
        try replaceProblems(in: context, with: snapshot)
        defaults.set(snapshot.version, forKey: versionKey)
        return true
    }

    static func replaceProblems(in context: ModelContext, with snapshot: Snapshot) throws {
        try context.delete(model: Problem.self)
        for record in snapshot.problems {
            context.insert(Problem(problemId: record.id, holdSet: record.holdSet, name: record.name,
                                   setter: record.setter, fontGrade: record.fontGrade, vGrade: record.vGrade,
                                   isBenchmark: record.isBenchmark, repeats: record.repeats, holds: record.holds))
        }
        try context.save()
    }
}
