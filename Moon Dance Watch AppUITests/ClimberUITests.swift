import XCTest

/// Tapping the climber beside the hold pictures opens the height picker.
final class ClimberUITests: XCTestCase {
    @MainActor
    func testTappingTheClimberOpensTheHeightPicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openScreen", "preview"]
        app.launch()
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 20) {
            notNow.tap()
        }
        // Not now pops back to Session; open the hold pictures from the grid.
        let grid = app.descendants(matching: .any)["holdGrid"]
        if !app.descendants(matching: .any)["problemPreview"].exists, grid.waitForExistence(timeout: 10) {
            grid.tap()
        }
        let preview = app.descendants(matching: .any)["problemPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        // The climber stands to the right of column K, its middle about 70% down.
        preview.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.72)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["heightPicker"].waitForExistence(timeout: 10))
    }
}
