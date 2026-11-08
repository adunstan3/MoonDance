import Foundation
import Observation
import SwiftData
import WatchKit

/// The short confirmation shown after logging, with Undo for 5 seconds.
@Observable
final class BannerModel {
    struct Banner: Equatable, Identifiable {
        enum Kind: Equatable { case attempt, sent, info, error }

        let id = UUID()
        let kind: Kind
        let text: String
        /// The log entry Undo removes.
        let entryID: UUID?
        /// The problem it was logged on; moving to another problem hides it.
        var problemID: String?
    }

    /// How long Undo stays available (5 seconds in the app).
    @ObservationIgnored let undoWindow: Duration

    private(set) var current: Banner?

    init(undoWindow: Duration = .seconds(5)) {
        self.undoWindow = undoWindow
    }

    func show(_ banner: Banner) {
        current = banner
        let id = banner.id
        let window = undoWindow
        Task { [weak self] in
            try? await Task.sleep(for: window)
            if self?.current?.id == id { self?.current = nil }
        }
    }

    func dismiss() { current = nil }
}

/// Everything the app shares: settings, the board, navigation, the session and
/// the store. App Intents (the Action Button) reach the app through `shared`.
@Observable
final class AppModel {
    static let shared = AppModel()

    let settings: AppSettings
    let board: BoardManager
    let router = Router()
    let session = SessionModel()
    let banner = BannerModel()
    @ObservationIgnored let container: ModelContainer

    var context: ModelContext { container.mainContext }

    init(settings: AppSettings, container: ModelContainer) {
        self.settings = settings
        self.container = container
        board = BoardManager(settings: settings)
        board.onJobEnded = { [weak self] status in self?.boardJobEnded(status) }
    }

    private convenience init() {
        let settings = AppSettings(defaults: RuntimeEnvironment.userDefaults)
        let container: ModelContainer
        do {
            container = try Store.makeContainer(inMemory: RuntimeEnvironment.isUITesting)
        } catch {
            fatalError("Couldn't open the data store: \(error)")
        }
        self.init(settings: settings, container: container)
    }

    /// The problem on the Session screen, loading the list if it isn't yet.
    var currentProblem: Problem? {
        if session.problems.isEmpty {
            session.reload(context: context, settings: settings)
        }
        return session.current
    }

    // MARK: - Logging

    func logAttempt() {
        guard let problem = currentProblem else { return }
        let entry = Logbook.logAttempt(problem, in: context)
        let total = Logbook.stats(for: problem, in: context).attempts
        banner.show(.init(kind: .attempt, text: "+1 attempt · \(total) total", entryID: entry.id,
                          problemID: problem.problemId))
        WKInterfaceDevice.current().play(.click)
    }

    func markSent() {
        guard let problem = currentProblem else { return }
        let entry = Logbook.logSend(problem, in: context)
        banner.show(.init(kind: .sent, text: "Sent", entryID: entry.id, problemID: problem.problemId))
        WKInterfaceDevice.current().play(.success)
    }

    func undoBanner() {
        guard let entryID = banner.current?.entryID else { return }
        Logbook.undo(entryID: entryID, in: context)
        banner.dismiss()
        WKInterfaceDevice.current().play(.directionDown)
    }

    func toggleProject() {
        guard let problem = currentProblem else { return }
        Logbook.toggleProject(problem, in: context)
    }

    // MARK: - Board

    /// Lights the current problem, or opens Find board first if no box is saved.
    func lightCurrent() {
        guard let problem = currentProblem else { return }
        guard settings.hasSavedBoard else {
            session.pendingLight = SessionModel.PendingLight(problemID: problem.problemId, holds: problem.holds)
            router.showSession()
            router.push(.findBoard)
            return
        }
        session.litProblemID = problem.problemId
        board.light(problem.holds)
    }

    func clearBoard() {
        board.clearBoard()
        session.litProblemID = nil
    }

    /// Haptics for every job; a red banner saying what went wrong for failures.
    func boardJobEnded(_ status: BoardManager.Status) {
        switch status {
        case .lit:
            WKInterfaceDevice.current().play(.success)
        case .cleared:
            WKInterfaceDevice.current().play(.click)
        case .failed(let failure):
            banner.show(.init(kind: .error, text: failure.message, entryID: nil))
            WKInterfaceDevice.current().play(.failure)
        case .idle, .connecting, .sending:
            break
        }
    }

    // MARK: - Action Button

    /// What the Action Button does, per Settings.
    func performActionButton() {
        router.showSession()
        switch settings.actionButtonMode {
        case .logAttempts: logAttempt()
        case .lightIt: lightCurrent()
        }
    }
}
