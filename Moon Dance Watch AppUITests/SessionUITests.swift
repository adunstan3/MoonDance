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

    /// Tapping the grid opens the hold-picture preview; the Crown zooms it; back on
    /// Session the Crown steps through problems again.
    @MainActor
    func testGridOpensPreviewAndCrownZooms() throws {
        let app = launchToSession()
        app.descendants(matching: .any)["holdGrid"].firstMatch.tap()
        let preview = app.descendants(matching: .any)["problemPreview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        let before = preview.value as? String
        XCTAssertEqual(before, "Zoom 100 percent")

        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        let zoomed = expectation(for: NSPredicate(format: "value != %@", before ?? ""), evaluatedWith: preview)
        wait(for: [zoomed], timeout: 5)

        app.buttons["previewBack"].tap()
        assertCrownChangesProblem(app, "after back from the preview")
    }

    /// Where a grid position is drawn in the preview at zoom 1, as a coordinate
    /// in the app's window. Mirrors PreviewGeometry: 1-cell gutters left and top,
    /// a 0.25-cell margin right and bottom, 36 pt reserved at the top and 8 at the
    /// bottom, the board fitted and centred.
    @MainActor
    private func previewPoint(_ app: XCUIApplication, column: Int, row: Int) -> XCUICoordinate {
        let size = app.windows.firstMatch.frame.size
        let (top, bottom) = (36.0, 8.0)
        let viewport = CGRect(x: 0, y: top, width: size.width, height: size.height - top - bottom)
        let (boardWidth, boardHeight) = (12.25, 19.25)
        let scale = min(viewport.width / boardWidth, viewport.height / boardHeight)
        let x = viewport.midX + (1 + Double(column) + 0.5 - boardWidth / 2) * scale
        let y = viewport.midY + (1 + Double(18 - row) + 0.5 - boardHeight / 2) * scale
        return app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// Long-press a hand hold for a high point, a start hold is refused, and a
    /// double-tap after zooming goes back to the whole board. The first problem
    /// under -uiTesting starts on E5 and F5 with a hand hold on E9.
    @MainActor
    func testLongPressMarksHighPoint() throws {
        let app = launchToSession()
        app.descendants(matching: .any)["holdGrid"].firstMatch.tap()
        let preview = app.descendants(matching: .any)["problemPreview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))

        previewPoint(app, column: 4, row: 9).press(forDuration: 0.7)
        XCTAssertTrue(app.staticTexts["High point E9"].waitForExistence(timeout: 3))

        previewPoint(app, column: 4, row: 5).press(forDuration: 0.7)
        XCTAssertTrue(app.staticTexts["Start holds can't be a high point"].waitForExistence(timeout: 3))

        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        let zoomed = expectation(for: NSPredicate(format: "value != %@", "Zoom 100 percent"), evaluatedWith: preview)
        wait(for: [zoomed], timeout: 5)
        preview.doubleTap()
        let reset = expectation(for: NSPredicate(format: "value == %@", "Zoom 100 percent"), evaluatedWith: preview)
        wait(for: [reset], timeout: 5)
    }

    /// In the hold pictures, tapping a hold opens its callout, whose pen opens the
    /// editor (Cancel the first time). Tapping an empty grid point shows nothing.
    /// The first problem under -uiTesting has a hand hold on E9.
    @MainActor
    func testBetaIsWrittenOnAHold() throws {
        let app = launchToSession()
        app.descendants(matching: .any)["holdGrid"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["problemPreview"].firstMatch.waitForExistence(timeout: 10))

        let callout = app.descendants(matching: .any)["holdCallout"].firstMatch
        previewPoint(app, column: 0, row: 1).tap()
        XCTAssertFalse(callout.waitForExistence(timeout: 1))
        sleep(1)
        previewPoint(app, column: 4, row: 9).tap()
        XCTAssertTrue(callout.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["E9"].exists)
        app.buttons["editHoldBeta"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["holdBetaField"].firstMatch.waitForExistence(timeout: 5))
        // The card's whole area opens the keyboard, even near its top edge.
        let card = app.descendants(matching: .any)["holdBetaCard"].firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.12)).tap()
        XCTAssertTrue(app.buttons["Emoji"].waitForExistence(timeout: 5), "the keyboard should open")
        // The keyboard's own Cancel, not the editor's.
        app.buttons.matching(NSPredicate(format: "label == 'Cancel' AND identifier != 'cancelHoldBeta'"))
            .firstMatch.tap()
        // New beta: Cancel, not Remove, and no Save (edits save as you go).
        XCTAssertTrue(app.buttons["cancelHoldBeta"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["removeHoldBeta"].exists)

        // Type a long note: it saves without a Save button and shows wrapped.
        card.tap()
        XCTAssertTrue(app.buttons["Emoji"].waitForExistence(timeout: 5))
        app.typeText("Heel hook then rock over to the crimp")
        app.buttons["Done"].tap()
        let wrapped = app.staticTexts["Heel hook then rock over to the crimp"]
        XCTAssertTrue(wrapped.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(wrapped.frame.height, 30, "long beta should wrap onto more than one line")

        // Back goes straight to the board, with no callout open.
        app.buttons["BackButton"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["problemPreview"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(callout.exists)
    }

    /// History rows: the pen on the right opens the log editor; the rest of the
    /// row opens the problem on Session.
    @MainActor
    func testHistoryPenOpensTheLogEditor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoLogs", "YES", "-page", "history"]
        app.launch()
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 20) { notNow.tap() }
        let row = app.descendants(matching: .any)["historyRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Edit log"].waitForExistence(timeout: 5))
        app.buttons["BackButton"].firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["problemName"].waitForExistence(timeout: 5))
    }
}
