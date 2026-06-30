import XCTest

final class TriggerIQUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--skip-onboarding",
            "--stub-analysis",
            "--in-memory-store"
        ]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    func testAppLaunchesToTodayTab() {
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    // MARK: - Tab navigation

    func testTabNavigationWorks() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    // MARK: - Meal logging

    func testLogMealSheetOpensAndCancels() {
        app.buttons["logMealButton"].tap()
        XCTAssertTrue(app.navigationBars["Log Meal"].waitForExistence(timeout: 3))

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    func testLogMealViaTextFullFlow() {
        logMealViaText("Grilled salmon with steamed broccoli")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    func testSavedMealAppearsInTodayList() {
        logMealViaText("Brown rice, black beans, avocado")

        XCTAssertTrue(
            app.staticTexts["Brown rice, black beans, avocado"]
                .waitForExistence(timeout: 3)
        )
    }

    func testSavedMealAppearsInHistory() {
        logMealViaText("Oatmeal with blueberries")

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))

        XCTAssertTrue(
            app.staticTexts["Oatmeal with blueberries"]
                .waitForExistence(timeout: 3)
        )
    }

    // MARK: - Helpers

    /// Finds the meal description input regardless of how SwiftUI renders it.
    private func findMealDescriptionField() -> XCUIElement {
        let placeholder = "e.g. grilled salmon, roasted vegetables, brown rice"
        // Try textView first (axis: .vertical TextField on iOS 16+)
        let asTextView = app.textViews[placeholder]
        if asTextView.waitForExistence(timeout: 2) { return asTextView }
        // Fall back to textField
        return app.textFields[placeholder]
    }

    private func logMealViaText(_ description: String) {
        app.buttons["logMealButton"].tap()
        _ = app.navigationBars["Log Meal"].waitForExistence(timeout: 3)

        // Swipe up to reveal the text entry section below the option buttons
        app.swipeUp()

        let textField = findMealDescriptionField()
        _ = textField.waitForExistence(timeout: 3)
        textField.tap()
        textField.typeText(description)

        // Dismiss the keyboard before tapping Analyze
        app.navigationBars["Log Meal"].tap()

        let analyzeButton = app.buttons["analyzeButton"]
        _ = analyzeButton.waitForExistence(timeout: 3)
        analyzeButton.tap()

        _ = app.navigationBars["Confirm Meal"].waitForExistence(timeout: 5)

        // Save button is at the bottom of the confirm list — scroll to it
        let saveButton = app.buttons["saveMealButton"]
        if !saveButton.isHittable { app.swipeUp() }
        saveButton.tap()

        _ = app.navigationBars["Today"].waitForExistence(timeout: 5)
    }
}
