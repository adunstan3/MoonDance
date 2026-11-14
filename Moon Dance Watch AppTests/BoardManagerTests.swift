import CoreBluetooth
import Foundation
import Testing
@testable import Moon_Dance_Watch_App

/// The listen-before-connect rules that keep the app from taking the shared
/// board from another climber. Bluetooth itself only runs on the real watch.
struct BoardManagerTests {
    let saved = UUID()
    let other = UUID()

    @Test func savedBoardOnlyMatchesItself() {
        #expect(BoardManager.isJobTarget(saved, savedBoardID: saved.uuidString))
        // Another LED box in the gym is never used once one is saved.
        #expect(!BoardManager.isJobTarget(other, savedBoardID: saved.uuidString))
    }

    /// Lots of unrelated devices offer the Nordic UART service, so with no saved
    /// board nothing is a target, however board-like it looks.
    @Test func withoutASavedBoardNothingMatches() {
        #expect(!BoardManager.isJobTarget(other, savedBoardID: nil))
        #expect(!BoardManager.isJobTarget(saved, savedBoardID: nil))
    }

    @MainActor @Test func aJobWithoutASavedBoardFailsAtOnce() {
        let defaults = UserDefaults(suiteName: "BoardManagerTests.noBoard")!
        defaults.removePersistentDomain(forName: "BoardManagerTests.noBoard")
        let board = BoardManager(settings: AppSettings(defaults: defaults))
        var ended: BoardManager.Status?
        board.onJobEnded = { ended = $0 }
        board.light([Hold(position: "A5", role: .start)])
        #expect(!board.isBusy)
        #expect(board.status == .failed(.noSavedBoard))
        #expect(ended == .failed(.noSavedBoard))
        #expect(!board.isScanning)
        #expect(BoardFailure.noSavedBoard.message.contains("Find board"))
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
        let settings = AppSettings(defaults: defaults)
        settings.boardID = UUID().uuidString
        let board = BoardManager(settings: settings)
        board.light([Hold(position: "A5", role: .start)])
        #expect(board.isBusy)
        board.clearBoard()
        #expect(board.lastJob == .light)
        #expect(board.log.entries.contains { $0.text.contains("Clear ignored") })
    }
}

/// What the shareable Bluetooth log records about devices heard while scanning.
struct DiscoveryLogTests {
    let id = UUID()
    let uart = CBUUID(string: BoardProtocol.uartServiceUUID)
    let maker = Data([0x59, 0x00, 0xab])

    @Test func aBoardIsLoggedInFull() {
        let line = BoardManager.discoveryLine(name: "Moonboard A", rssi: -60, identifier: id, services: [uart],
                                              makerData: maker, looksLikeBoard: true)
        #expect(line.contains("Moonboard A"))
        #expect(line.contains("rssi -60"))
        #expect(line.contains(id.uuidString))
        #expect(line.contains(uart.uuidString))
        #expect(line.contains("5900ab"))
    }

    @Test func otherDevicesOnlyGetNameAndSignal() {
        let line = BoardManager.discoveryLine(name: "Someone's earbuds", rssi: -75, identifier: id, services: [],
                                              makerData: maker, looksLikeBoard: false)
        #expect(line == "Found other device \"Someone's earbuds\" rssi -75")
        #expect(!line.contains(id.uuidString))
        #expect(!line.contains("5900ab"))
    }
}

struct ExportFileTests {
    @Test func leftoverExportFileIsRemoved() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "moondance-test-\(UUID().uuidString).csv")
        try "date\n".write(to: url, atomically: true, encoding: .utf8)
        LogExport.removeLeftoverFile(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path()))
        // Nothing there is fine too.
        LogExport.removeLeftoverFile(at: url)
    }
}
