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
            CSVExport.Row(date: date(8, 19, 5), holdSet: "2024", problemId: "d1", problem: "Dunes", grade: "V5 6C",
                          kind: .send),
            CSVExport.Row(date: date(4, 18, 30), holdSet: "2016", problemId: "j1", problem: "Josh 1", grade: "V4 6B",
                          kind: .attempt),
            CSVExport.Row(date: date(9, 20, 0), holdSet: "2024", problemId: "d1", problem: "Dunes", grade: "V5 6C",
                          kind: .highPoint, hold: "G13"),
        ]
        let lines = CSVExport.csv(rows: rows, timeZone: newYork).split(separator: "\n").map(String.init)
        #expect(lines == [
            "date,time,hold_set,problem_id,problem,grade,type,hold,note",
            "2026-11-04,18:30:00,2016,j1,Josh 1,V4 6B,attempt,,",
            "2026-11-08,19:05:00,2024,d1,Dunes,V5 6C,send,,",
            "2026-11-09,20:00:00,2024,d1,Dunes,V5 6C,high_point,G13,",
        ])
    }

    @Test func escapesCommasAndQuotes() {
        #expect(CSVExport.escape("plain") == "plain")
        #expect(CSVExport.escape("Crimp, Theory") == "\"Crimp, Theory\"")
        #expect(CSVExport.escape("The \"Moon\"") == "\"The \"\"Moon\"\"\"")
    }

    @Test func emptyLogIsJustTheHeader() {
        #expect(CSVExport.csv(rows: []) == "date,time,hold_set,problem_id,problem,grade,type,hold,note\n")
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
        context.insert(Project(problemId: "p1", holdSet: "2024", dateAdded: Date(timeIntervalSince1970: 400)))
        // A current high point from before markings were recorded (no mark)…
        context.insert(HighPoint(problemId: "p1", holdSet: "2024", position: "G13", date: Date(timeIntervalSince1970: 500)))
        // …and a later one marked the usual way: the mark matches the current one.
        let later = Date(timeIntervalSince1970: 600)
        context.insert(HighPointMark(problemId: "gone", holdSet: "2016", position: "H15", date: later))
        context.insert(HighPoint(problemId: "gone", holdSet: "2016", position: "H15", date: later))
        context.insert(BetaNote(problemId: "p1", holdSet: "2024", text: "Heel hook, then \"jump\"",
                                updated: Date(timeIntervalSince1970: 700)))
        try context.save()

        let export = LogExport.make(context: context)
        #expect(export.entryCount == 3)
        #expect(export.starCount == 1)
        #expect(export.highPointCount == 2)
        #expect(export.betaCount == 1)
        let lines = export.csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.count == 9)
        #expect(lines[1].hasSuffix(",2024,p1,\"Crimp, Theory\",V5 6C+,attempt,,"))
        #expect(lines[2].hasSuffix(",send,,"))
        // A problem no longer in the snapshot is still exported, by id.
        #expect(lines[3].hasSuffix(",2016,gone,,,attempt,,"))
        #expect(lines[4].hasSuffix(",2024,p1,\"Crimp, Theory\",V5 6C+,star,,"))
        #expect(lines[5].hasSuffix(",high_point,G13,"))
        #expect(lines[6].hasSuffix(",2016,gone,,,high_point,H15,"))
        #expect(lines[7].hasSuffix(",beta,,\"Heel hook, then \"\"jump\"\"\""))
    }
}
