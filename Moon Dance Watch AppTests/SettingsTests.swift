import Foundation
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct SettingsTests {
    private func freshDefaults() throws -> UserDefaults {
        let name = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firstLaunchDefaults() throws {
        let settings = AppSettings(defaults: try freshDefaults())
        #expect(settings.holdSet == .mb2024)
        #expect(settings.lastGrade == 5)
        #expect(settings.actionButtonMode == .logAttempts)
        #expect(!settings.benchmarksOnly)
        #expect(!settings.hasSavedBoard)
        #expect(settings.lastExport == nil)
    }

    @Test func settingsPersist() throws {
        let defaults = try freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.holdSet = .mb2016
        settings.lastGrade = 7
        settings.actionButtonMode = .lightIt
        settings.boardID = "ABC"
        settings.boardName = "MoonBoard 123456789012"
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        settings.lastExport = date

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.holdSet == .mb2016)
        #expect(reloaded.lastGrade == 7)
        #expect(reloaded.actionButtonMode == .lightIt)
        #expect(reloaded.boardID == "ABC")
        #expect(reloaded.lastExport == date)
    }

    @Test func savedGradeOutsideThePickerFallsBackToV5() throws {
        let defaults = try freshDefaults()
        defaults.set(2, forKey: AppSettings.Keys.lastGrade)
        #expect(AppSettings(defaults: defaults).lastGrade == 5)
    }

    @Test func forgetBoardClearsIt() throws {
        let defaults = try freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.boardID = "ABC"
        settings.boardName = "MoonBoard"
        settings.forgetBoard()
        #expect(!settings.hasSavedBoard)
        #expect(AppSettings(defaults: defaults).boardID == nil)
    }

    @Test func boardSaveStoresIdentifierAndName() throws {
        let settings = AppSettings(defaults: try freshDefaults())
        let manager = BoardManager(settings: settings)
        let id = UUID()
        manager.save(DiscoveredBoard(id: id, name: "MoonBoard A", rssi: -50, looksLikeBoard: true))
        #expect(settings.boardID == id.uuidString)
        #expect(settings.boardName == "MoonBoard A")
        #expect(manager.log.entries.last?.text.contains("Saved board") == true)
    }
}

struct BoardIdentityTests {
    @Test func usesTwelveDigitIDFromName() {
        #expect(BoardIdentity.displayID(name: "MoonBoard 482910375561", identifier: "6F1C2A90-1111") == "482910375561")
        #expect(BoardIdentity.displayName("MoonBoard 482910375561") == "MoonBoard")
    }

    @Test func fallsBackToIdentifier() {
        #expect(BoardIdentity.displayID(name: "Moonboard A", identifier: "6f1c2a90-1111") == "6F1C2A90")
        #expect(BoardIdentity.displayID(name: nil, identifier: "abcd1234-5678") == "ABCD1234")
        #expect(BoardIdentity.displayName("Moonboard A") == "Moonboard A")
        #expect(BoardIdentity.displayName("123456789012") == "MoonBoard LED")
    }

    @Test func signalStrengthBuckets() {
        func signal(_ rssi: Int) -> DiscoveredBoard.Signal {
            DiscoveredBoard(id: UUID(), name: "", rssi: rssi, looksLikeBoard: true).signal
        }
        #expect(signal(-50) == .near)
        #expect(signal(-70) == .medium)
        #expect(signal(-90) == .far)
    }
}

@MainActor
struct BoardFailureTests {
    @Test func everyFailureHasAShortMessageAndALogLine() {
        let failures: [BoardFailure] = [
            .bluetoothUnavailable, .bluetoothNotAllowed, .bluetoothOff, .timedOut(seconds: 15),
            .connectFailed("x"), .disconnected, .discoveryFailed("x"), .serviceMissing,
            .characteristicMissing, .notWritable, .writeFailed(packet: 2, reason: "x"),
        ]
        for failure in failures {
            #expect(!failure.message.isEmpty)
            #expect(failure.message.count <= 60, "\(failure.message) is too long for the banner")
            #expect(!failure.logText.isEmpty)
        }
        #expect(BoardFailure.timedOut(seconds: 15).logText.contains("15 s"))
    }

    @Test func failedJobShowsARedBanner() throws {
        let name = "failure-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let model = AppModel(settings: AppSettings(defaults: defaults), container: try Store.makeContainer(inMemory: true))
        model.boardJobEnded(.failed(.timedOut(seconds: 15)))
        #expect(model.banner.current?.kind == .error)
        #expect(model.banner.current?.text == BoardFailure.timedOut(seconds: 15).message)
        #expect(model.banner.current?.entryID == nil)

        model.banner.dismiss()
        model.boardJobEnded(.lit)
        #expect(model.banner.current == nil)
    }
}
