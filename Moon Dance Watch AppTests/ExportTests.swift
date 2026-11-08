import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Moon_Dance_Watch_App

struct CSVExportTests {
    let newYork = TimeZone(identifier: "America/New_York")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func headerAndRowsOldestFirst() {
        let rows = [
            CSVExport.Row(date: date(8, 19, 5), holdSet: "2024", problem: "Dunes", grade: "V5 6C", isSend: true),
            CSVExport.Row(date: date(4, 18, 30), holdSet: "2016", problem: "Josh 1", grade: "V4 6B", isSend: false),
        ]
        let lines = CSVExport.csv(rows: rows, timeZone: newYork).split(separator: "\n").map(String.init)
        #expect(lines == [
            "date,time,hold_set,problem,grade,type",
            "2026-11-04,18:30:00,2016,Josh 1,V4 6B,attempt",
            "2026-11-08,19:05:00,2024,Dunes,V5 6C,send",
        ])
    }

    @Test func escapesCommasAndQuotes() {
        #expect(CSVExport.escape("plain") == "plain")
        #expect(CSVExport.escape("Crimp, Theory") == "\"Crimp, Theory\"")
        #expect(CSVExport.escape("The \"Moon\"") == "\"The \"\"Moon\"\"\"")
    }

    @Test func emptyLogIsJustTheHeader() {
        #expect(CSVExport.csv(rows: []) == "date,time,hold_set,problem,grade,type\n")
    }
}

@MainActor
struct LogExportTests {
    @Test func includesBothHoldSetsAndNamesProblems() throws {
        let container = try Store.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Problem(problemId: "p1", holdSet: "2024", name: "Crimp, Theory", setter: "", fontGrade: "6C+",
                               vGrade: 5, isBenchmark: true, repeats: 1, holds: []))
        context.insert(LogEntry(problemId: "p1", holdSet: "2024", date: Date(timeIntervalSince1970: 100), isSend: false))
        context.insert(LogEntry(problemId: "p1", holdSet: "2024", date: Date(timeIntervalSince1970: 200), isSend: true))
        context.insert(LogEntry(problemId: "gone", holdSet: "2016", date: Date(timeIntervalSince1970: 300), isSend: false))
        try context.save()

        let export = LogExport.make(context: context)
        #expect(export.entryCount == 3)
        let lines = export.csv.split(separator: "\n")
        #expect(lines.count == 4)
        #expect(lines[1].hasSuffix(",2024,\"Crimp, Theory\",V5 6C+,attempt"))
        #expect(lines[2].hasSuffix(",send"))
        // A problem no longer in the snapshot is still exported, by id.
        #expect(lines[3].hasSuffix(",2016,gone,,attempt"))
    }
}
