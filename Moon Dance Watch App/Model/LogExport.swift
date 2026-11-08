import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The logbook as CSV: date, time, hold set, problem, grade, attempt or send.
nonisolated enum CSVExport {
    static let filename = "moondance-log.csv"
    static let header = "date,time,hold_set,problem,grade,type"

    struct Row: Sendable {
        let date: Date
        let holdSet: String
        let problem: String
        let grade: String
        let isSend: Bool
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
             row.problem,
             row.grade,
             row.isSend ? "send" : "attempt"]
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
    let entryCount: Int

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
    /// Every log entry, both hold sets, with problem names and grades from the snapshot.
    @MainActor
    static func make(context: ModelContext) -> LogExport {
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let problems = SessionModel.problems(ids: Set(entries.map(\.problemId)), context: context)
        let rows = entries.map { entry in
            let problem = problems[entry.problemId]
            return CSVExport.Row(date: entry.date,
                                 holdSet: entry.holdSet,
                                 // A problem missing from a newer snapshot keeps its id.
                                 problem: problem?.name ?? entry.problemId,
                                 grade: problem.map { "\(Grades.vName($0.vGrade)) \($0.fontGrade)" } ?? "",
                                 isSend: entry.isSend)
        }
        return LogExport(csv: CSVExport.csv(rows: rows), entryCount: entries.count)
    }
}
