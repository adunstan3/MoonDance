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
        /// The send Unsend turned into an attempt; Undo makes it a send again.
        var unsentEntryID: UUID?

        var canUndo: Bool { entryID != nil || unsentEntryID != nil }
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
    /// Set when the saved log couldn't be opened. The app then runs on an empty
    /// in-memory store (nothing is saved) and shows an error screen first.
    let storeError: String?

    var context: ModelContext { container.mainContext }

    init(settings: AppSettings, container: ModelContainer, storeError: String? = nil) {
        self.settings = settings
        self.container = container
        self.storeError = storeError
        board = BoardManager(settings: settings)
        board.onJobEnded = { [weak self] status in self?.boardJobEnded(status) }
        Logbook.onSaveError = { [weak self] error in self?.saveFailed(error) }
    }

    private convenience init() {
        let settings = AppSettings(defaults: RuntimeEnvironment.userDefaults)
        var storeError: String?
        let container: ModelContainer
        do {
            #if DEBUG
            if RuntimeEnvironment.debugValue("demoStoreError") != nil {
                throw CocoaError(.fileReadCorruptFile)
            }
            #endif
            container = try Store.makeContainer(inMemory: RuntimeEnvironment.isUITesting)
        } catch {
            storeError = error.localizedDescription
            do {
                container = try Store.makeContainer(inMemory: true)
            } catch {
                fatalError("Couldn't open even an in-memory store: \(error)")
            }
        }
        self.init(settings: settings, container: container, storeError: storeError)
    }

    private func saveFailed(_ error: Error) {
        board.log.error("Couldn't save the log: \(error.localizedDescription)")
        banner.show(.init(kind: .error, text: "Couldn't save. Try again", entryID: nil))
        WKInterfaceDevice.current().play(.failure)
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
        send(problem)
    }

    private func send(_ problem: Problem) {
        let entry = Logbook.logSend(problem, in: context)
        banner.show(.init(kind: .sent, text: "Sent", entryID: entry.id, problemID: problem.problemId))
        WKInterfaceDevice.current().play(.success)
    }

    /// Turns the latest send back into an attempt; earlier tries and sends stay.
    /// Undo (5 seconds) makes it a send again. History's log editor fixes anything else.
    func unsend() {
        guard let problem = currentProblem,
              let changed = Logbook.unsendLatest(problem, in: context) else { return }
        let stats = Logbook.stats(for: problem, in: context)
        let text = stats.isSent
            ? "Unsent 1 · \(stats.sends) left"
            : "Unsent · \(stats.attempts) \(stats.attempts == 1 ? "try" : "tries")"
        banner.show(.init(kind: .info, text: text, entryID: nil, problemID: problem.problemId,
                          unsentEntryID: changed))
        WKInterfaceDevice.current().play(.directionDown)
    }

    func undoBanner() {
        guard let current = banner.current, current.canUndo else { return }
        if let entryID = current.entryID {
            Logbook.undo(entryID: entryID, in: context)
        }
        if let unsent = current.unsentEntryID {
            Logbook.setSend(true, entryID: unsent, in: context)
        }
        banner.dismiss()
        WKInterfaceDevice.current().play(.directionDown)
    }

    enum HighPointResult: Equatable {
        /// This hand hold is now the high point (replacing any other).
        case marked(String)
        /// It already was; now there's none.
        case cleared
        /// It's the finish hold, so the problem was logged as sent.
        case sent
        /// Start holds can't be a high point.
        case startHold
        /// That position isn't one of the problem's holds.
        case notInProblem
    }

    /// Long-press on a hold in the preview. One high point per problem: marking a
    /// hand hold replaces the old one (or clears it if it's the same hold); the
    /// finish hold logs a send instead; start holds can't be marked.
    @discardableResult
    func markHighPoint(_ position: GridPosition, on problem: Problem) -> HighPointResult {
        guard let hold = problem.holds.first(where: { GridPosition($0.position) == position }) else {
            return .notInProblem
        }
        switch hold.role {
        case .start:
            WKInterfaceDevice.current().play(.failure)
            return .startHold
        case .finish:
            send(problem)
            return .sent
        case .hand:
            if Logbook.highPoint(for: problem, in: context) == position.name {
                Logbook.setHighPoint(nil, for: problem, in: context)
                WKInterfaceDevice.current().play(.directionDown)
                return .cleared
            }
            Logbook.setHighPoint(position.name, for: problem, in: context)
            WKInterfaceDevice.current().play(.success)
            return .marked(position.name)
        }
    }

    /// Stars or unstars the current problem; starred problems pin to the top of the list.
    func toggleProject() {
        guard let problem = currentProblem else { return }
        Logbook.toggleProject(problem, in: context)
        session.reload(context: context, settings: settings, keeping: problem.problemId)
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
}
