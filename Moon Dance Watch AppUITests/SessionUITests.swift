import XCTest

/// Interaction checks that unit tests can't cover. Slow (they launch the app),
/// so they run separately: scripts/uitest.sh
final class SessionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchToSession() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        // First launch offers Find board; skip it.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 30) {
            notNow.tap()
        }
        XCTAssertTrue(app.buttons["problemName"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testCrownStepsToTheNextProblem() throws {
        let app = launchToSession()
        let name = app.buttons["problemName"]
        let first = name.label

        XCUIDevice.shared.rotateDigitalCrown(delta: 0.3)
        expectation(for: NSPredicate(format: "label != %@", first), evaluatedWith: name)
        waitForExpectations(timeout: 5)
        let second = name.label

        // Turning well past the start stops at the first problem.
        XCUIDevice.shared.rotateDigitalCrown(delta: -1.0)
        expectation(for: NSPredicate(format: "label == %@", first), evaluatedWith: name)
        waitForExpectations(timeout: 5)
        XCTAssertNotEqual(first, second)
    }

    @MainActor
    private func assertCrownChangesProblem(_ app: XCUIApplication, _ message: String) {
        let name = app.buttons["problemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), message)
        let before = name.label
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.3)
        let changed = expectation(for: NSPredicate(format: "label != %@", before), evaluatedWith: name)
        wait(for: [changed], timeout: 5)
    }

    @MainActor
    func testCrownStillWorksAfterOpeningTheList() throws {
        let app = launchToSession()
        app.buttons["problemName"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        assertCrownChangesProblem(app, "after back from the list")
    }

    @MainActor
    func testCrownStillWorksAfterSwipingToHistoryAndBack() throws {
        let app = launchToSession()
        app.swipeLeft()
        sleep(1)
        app.swipeRight()
        sleep(1)
        assertCrownChangesProblem(app, "after swiping to History and back")
    }

    /// A nudge (a tenth of a rotation) doesn't move: at the gym `.high` sensitivity
    /// stepped on every tiny touch and was too fast, so it's `.low` now.
    /// testCrownStepsToTheNextProblem
    /// checks a 0.3 turn still moves, so it isn't too stiff either.
    @MainActor
    func testCrownNudgeDoesNotStep() throws {
        let app = launchToSession()
        let name = app.buttons["problemName"]
        let before = name.label
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.1)
        sleep(2)
        XCTAssertEqual(name.label, before)
    }
}
