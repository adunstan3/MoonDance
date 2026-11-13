import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct LoggingTests {
    let model: AppModel

    init() throws {
        let name = "logging-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        let container = try Store.makeContainer(inMemory: true)
        let context = container.mainContext
        for (id, repeats) in [("p1", 20), ("p2", 10)] {
            context.insert(Problem(problemId: id, holdSet: "2024", name: id, setter: "", fontGrade: "6C+", vGrade: 5,
                                   isBenchmark: false, repeats: repeats,
                                   holds: [Hold(position: "D5", role: .start), Hold(position: "F18", role: .finish)]))
        }
        try context.save()
        model = AppModel(settings: settings, container: container)
        model.session.reload(context: context, settings: settings)
    }

    private var current: Problem { model.session.current! }
    private var stats: ProblemStats { Logbook.stats(for: current, in: model.context) }

    @Test func attemptLogsOneEntryAndShowsBanner() {
        model.logAttempt()
        model.logAttempt()
        #expect(stats == ProblemStats(attempts: 2, sends: 0))
        #expect(model.banner.current?.kind == .attempt)
        #expect(model.banner.current?.text == "+1 attempt · 2 total")
    }

    @Test func sendCountsAsAnAttempt() {
        model.logAttempt()
        model.markSent()
        #expect(stats == ProblemStats(attempts: 2, sends: 1))
        #expect(model.banner.current?.kind == .sent)
        // A problem can be sent more than once.
        model.markSent()
        #expect(stats.sends == 2)
    }

    @Test func unsendTurnsOnlyTheLatestSendIntoAnAttempt() throws {
        model.logAttempt()
        model.logAttempt()
        model.markSent()
        // Another problem's log is left alone.
        model.session.step(by: 1, settings: model.settings)
        model.logAttempt()
        model.session.step(by: -1, settings: model.settings)
        #expect(stats == ProblemStats(attempts: 3, sends: 1))

        model.unsend()
        // The tries are kept; only the send is gone.
        #expect(stats == ProblemStats(attempts: 3, sends: 0))
        #expect(model.banner.current?.text == "Unsent · 3 tries")
        #expect(model.banner.current?.canUndo == true)
        #expect(try model.context.fetchCount(FetchDescriptor<LogEntry>()) == 4)

        model.undoBanner()
        #expect(stats == ProblemStats(attempts: 3, sends: 1))
        #expect(model.banner.current == nil)
    }

    @Test func unsendKeepsEarlierSends() throws {
        model.markSent()
        model.markSent()
        model.unsend()
        #expect(stats == ProblemStats(attempts: 2, sends: 1))
        #expect(model.banner.current?.text == "Unsent 1 · 1 left")
        // The latest send is the one undone.
        let entries = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.map(\.isSend) == [true, false])
    }

    @Test func logEditorEditsOneDay() throws {
        let problem = current
        let context = model.context
        let today = Date.now
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
        Logbook.logAttempt(problem, in: context, at: yesterday)
        let first = Logbook.logAttempt(problem, in: context, at: today.addingTimeInterval(-60))
        Logbook.logAttempt(problem, in: context, at: today)
        let onDay = Logbook.entries(problemId: problem.problemId, holdSet: problem.holdSet, on: today, in: context)
        #expect(onDay.count == 2)

        Logbook.setSend(true, entryID: first.id, in: context)
        #expect(stats == ProblemStats(attempts: 3, sends: 1))

        Logbook.delete(onDay, in: context)
        // Yesterday's entry is untouched.
        #expect(stats == ProblemStats(attempts: 1, sends: 0))
    }

    @Test func unsendWithNothingLoggedDoesNothing() {
        model.unsend()
        #expect(model.banner.current == nil)
    }

    @Test func undoRemovesOnlyTheLastEntry() {
        model.logAttempt()
        model.logAttempt()
        model.undoBanner()
        #expect(stats.attempts == 1)
        #expect(model.banner.current == nil)
        // Nothing left to undo.
        model.undoBanner()
        #expect(stats.attempts == 1)
    }

    @Test func entriesRecordProblemHoldSetAndTime() throws {
        let before = Date.now
        model.markSent()
        let entry = try #require(try model.context.fetch(FetchDescriptor<LogEntry>()).first)
        #expect(entry.problemId == "p1")
        #expect(entry.holdSet == "2024")
        #expect(entry.isSend)
        #expect(entry.date >= before)
    }

    @Test func starringPinsTheProblemAndKeepsItOnScreen() {
        model.session.step(by: 1, settings: model.settings)
        #expect(current.problemId == "p2")
        model.toggleProject()
        #expect(model.session.problems.map(\.problemId) == ["p2", "p1"])
        #expect(current.problemId == "p2")
        model.toggleProject()
        #expect(model.session.problems.map(\.problemId) == ["p1", "p2"])
        #expect(current.problemId == "p2")
    }

    @Test func starTogglesAndSurvivesASend() {
        model.toggleProject()
        #expect(Logbook.isProject(current, in: model.context))
        model.markSent()
        #expect(Logbook.isProject(current, in: model.context))
        model.toggleProject()
        #expect(!Logbook.isProject(current, in: model.context))
    }

    @Test func lightItWithNoSavedBoardOpensFindBoard() {
        model.router.page = .history
        model.lightCurrent()
        // Remembers the problem so it lights once a board is picked.
        #expect(model.session.pendingLight?.problemID == "p1")
        #expect(model.router.page == .session)
        #expect(model.router.path.count == 1)
        #expect(stats.attempts == 0)
    }

    @Test func bannerClearsAfterUndoWindow() async throws {
        let banner = BannerModel(undoWindow: .milliseconds(200))
        banner.show(.init(kind: .info, text: "hi", entryID: nil))
        #expect(banner.current != nil)
        // Poll: other tests share the main actor, so the timer may fire a little late.
        for _ in 0..<40 where banner.current != nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(banner.current == nil)
        #expect(BannerModel().undoWindow == .seconds(5))
    }
}

struct HistoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func groupsByCalendarDayNewestFirst() {
        let items = [
            History.Item(problemId: "a", date: date(4, 19), isSend: false),
            History.Item(problemId: "a", date: date(4, 19, 5), isSend: false),
            History.Item(problemId: "b", date: date(8, 18), isSend: false),
            History.Item(problemId: "b", date: date(8, 18, 10), isSend: true),
            History.Item(problemId: "a", date: date(8, 20), isSend: false),
        ]
        let days = History.days(from: items, calendar: calendar)
        #expect(days.count == 2)
        #expect(days[0].date == calendar.startOfDay(for: date(8, 12)))
        // Most recent activity first within the day.
        #expect(days[0].problems.map(\.problemId) == ["a", "b"])
        #expect(days[0].attempts == 3)
        #expect(days[0].sends == 1)
        #expect(days[0].problems[1].isSent)
        #expect(days[1].problems.map(\.attempts) == [2])
        #expect(History.summary(for: days[0]) == "2 problems · 3 attempts · 1 send")
    }

    @Test func lateNightStaysOnItsOwnDay() {
        // 11:30 pm and 12:30 am the next day are different sessions in the watch's time zone.
        let items = [
            History.Item(problemId: "a", date: date(7, 23, 30), isSend: false),
            History.Item(problemId: "a", date: date(8, 0, 30), isSend: false),
        ]
        #expect(History.days(from: items, calendar: calendar).count == 2)
    }

    @Test func dayTitles() {
        let now = date(8, 12)
        #expect(History.title(for: calendar.startOfDay(for: now), now: now, calendar: calendar) == "Today")
        #expect(History.title(for: calendar.startOfDay(for: date(7, 9)), now: now, calendar: calendar) == "Yesterday")
        let title = History.title(for: calendar.startOfDay(for: date(4, 9)), now: now, calendar: calendar)
        #expect(title.contains("Nov"))
        #expect(title.contains("4"))
    }
}
