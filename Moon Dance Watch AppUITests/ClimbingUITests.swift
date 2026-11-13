import XCTest

/// Starting a climbing session (Settings › Stay open): Health asks for
/// permission once, then the session runs and the card says "On since …".
final class ClimbingUITests: XCTestCase {
    @MainActor
    func testClimbingSessionStartsAfterHealthPermission() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-startClimbing", "YES", "-page", "settings"]
        app.launch()
        // The Health permission sheet is system UI (Carousel), not the app's.
        let system = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        let review = system.buttons["UIA.Health.WatchAuthSheet.ReviewButton"]
        if review.waitForExistence(timeout: 20) {
            review.tap()
            // Turn on "All Requested Data", then confirm at the bottom.
            let allData = system.switches["UIA.Health.WatchAuthSheet.SwitchOutlet"].firstMatch
            XCTAssertTrue(allData.waitForExistence(timeout: 10))
            allData.tap()
            for _ in 0..<4 { system.swipeUp() }
            let done = system.cells["UIA.Health.WatchAuthSheet.ConfigureCell.Button"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            done.tap()
        }
        // First launch offers Find board; skip it.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 5) {
            notNow.tap()
        }
        let card = app.buttons["climbingSession"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let running = NSPredicate(format: "label CONTAINS %@", "On since")
        expectation(for: running, evaluatedWith: card)
        waitForExpectations(timeout: 15)
    }
}
