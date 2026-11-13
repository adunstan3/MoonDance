import Foundation
import Testing
@testable import Moon_Dance_Watch_App

/// The listen-before-connect rules that keep the app from taking the shared
/// board from another climber. Bluetooth itself only runs on the real watch.
struct BoardManagerTests {
    let saved = UUID()
    let other = UUID()

    @Test func savedBoardOnlyMatchesItself() {
        #expect(BoardManager.isJobTarget(saved, looksLikeBoard: true, savedBoardID: saved.uuidString))
        // Another LED box in the gym is never used once one is saved.
        #expect(!BoardManager.isJobTarget(other, looksLikeBoard: true, savedBoardID: saved.uuidString))
    }

    @Test func withoutASavedBoardTheFirstLEDBoxMatches() {
        #expect(BoardManager.isJobTarget(other, looksLikeBoard: true, savedBoardID: nil))
        #expect(!BoardManager.isJobTarget(other, looksLikeBoard: false, savedBoardID: nil))
    }

    /// Listening must give up before a connection attempt would, and both well
    /// before the whole job times out, so a busy board fails fast and we never
    /// leave a connection request waiting to grab the board later.
    @Test func timeoutsAreOrdered() {
        #expect(BoardManager.advertisingWindow < BoardManager.connectTimeout)
        #expect(BoardManager.advertisingWindow + BoardManager.connectTimeout < BoardManager.jobTimeout)
        #expect(BoardManager.advertisingWindow <= .seconds(5))
    }

    @MainActor @Test func aSecondJobIsIgnoredWhileBusy() {
        let defaults = UserDefaults(suiteName: "BoardManagerTests")!
        defaults.removePersistentDomain(forName: "BoardManagerTests")
        let board = BoardManager(settings: AppSettings(defaults: defaults))
        board.light([Hold(position: "A5", role: .start)])
        #expect(board.isBusy)
        board.clearBoard()
        #expect(board.lastJob == .light)
        #expect(board.log.entries.contains { $0.text.contains("Clear ignored") })
    }
}
