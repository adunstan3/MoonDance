import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The logbook as CSV, a complete backup: one row per attempt, send, project
/// star, high point marked and hold beta. Columns: date, time, hold set, problem
/// id, problem name, grade, type (attempt, send, star, high_point, beta), hold (the
/// high point's or beta's position) and note (the beta text).
nonisolated enum CSVExport {
    static let filename = "moondance-log.csv"
    static let header = "date,time,hold_set,problem_id,problem,grade,type,hold,note"

    enum Kind: String, Sendable {
        case attempt, send, star, beta
        case highPoint = "high_point"
    }

    struct Row: Sendable {
        let date: Date
        let holdSet: String
        let problemId: String
        let problem: String
        let grade: String
        let kind: Kind
        var hold: String = ""
        var note: String = ""
    }

    /// Oldest first; dates and times in the watch's time zone.
    static func csv(rows: [Row], timeZone: TimeZone = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm:ss"

        let lines = rows.sorted { $0.date < $1.date }.map { row in
            [dateFormatter.string(from: row.date),
             timeFormatter.string(from: row.date),
             row.holdSet,
             row.problemId,
             row.problem,
             row.grade,
             row.kind.rawValue,
             row.hold,
             row.note]
                .map(escape)
                .joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n") + "\n"
    }

    /// Quotes a field that holds a comma, quote or line break.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// What the share sheet sends: a .csv file, or the same text where a file isn't taken.
nonisolated struct LogExport: Transferable {
    let csv: String
    /// Attempts and sends.
    let entryCount: Int
    var starCount = 0
    var highPointCount = 0
    var betaCount = 0

    var isEmpty: Bool { entryCount + starCount + highPointCount + betaCount == 0 }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appending(path: CSVExport.filename)
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
        ProxyRepresentation(exporting: \.csv)
    }
}

extension LogExport {
    /// Every log entry, star, high point marked and beta note, both hold sets, with
    /// problem names and grades from the snapshot.
    @MainActor
    static func make(context: ModelContext) -> LogExport {
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>())) ?? []
        let stars = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let marks = (try? context.fetch(FetchDescriptor<HighPointMark>())) ?? []
        // A current high point set before markings were recorded has no mark.
        let marked = Set(marks.map { "\($0.problemId)|\($0.holdSet)|\($0.position)|\($0.date.timeIntervalSince1970)" })
        let unmarked = ((try? context.fetch(FetchDescriptor<HighPoint>())) ?? []).filter {
            !marked.contains("\($0.problemId)|\($0.holdSet)|\($0.position)|\($0.date.timeIntervalSince1970)")
        }
        let notes = (try? context.fetch(FetchDescriptor<BetaNote>())) ?? []
        let ids = Set(entries.map(\.problemId) + stars.map(\.problemId) + marks.map(\.problemId)
                      + unmarked.map(\.problemId) + notes.map(\.problemId))
        let problems = SessionModel.problems(ids: ids, context: context)

        func row(_ date: Date, _ holdSet: String, _ id: String, _ kind: CSVExport.Kind, hold: String = "",
                 note: String = "") -> CSVExport.Row {
            let problem = problems[id]
            return CSVExport.Row(date: date, holdSet: holdSet, problemId: id,
                                 // A problem missing from a newer snapshot is still listed by id.
                                 problem: problem?.name ?? "",
                                 grade: problem.map { "\(Grades.vName($0.vGrade)) \($0.fontGrade)" } ?? "",
                                 kind: kind, hold: hold, note: note)
        }
        let rows = entries.map { row($0.date, $0.holdSet, $0.problemId, $0.isSend ? .send : .attempt) }
            + stars.map { row($0.dateAdded, $0.holdSet, $0.problemId, .star) }
            + marks.map { row($0.date, $0.holdSet, $0.problemId, .highPoint, hold: $0.position) }
            + unmarked.map { row($0.date, $0.holdSet, $0.problemId, .highPoint, hold: $0.position) }
            + notes.map { row($0.updated, $0.holdSet, $0.problemId, .beta, hold: $0.position, note: $0.text) }
        return LogExport(csv: CSVExport.csv(rows: rows), entryCount: entries.count, starCount: stars.count,
                         highPointCount: marks.count + unmarked.count, betaCount: notes.count)
    }
}
