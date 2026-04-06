import XCTest

final class UlogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsReadyStateAndEmptyConversation() throws {
        let app = launchApplication()
        let inputField = app.textFields["Message Input"]
        let clearButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch

        XCTAssertTrue(app.staticTexts["Start a conversation"].waitForExistence(timeout: 5))
        XCTAssertTrue(inputField.isEnabled)
        XCTAssertFalse(clearButton.isEnabled)
    }

    @MainActor
    func testSendMessageStreamsAssistantReply() throws {
        let app = launchApplication()
        let inputField = app.textFields["Message Input"]
        let clearButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Hello from UI tests")
        app.buttons["Send Message"].click()

        XCTAssertTrue(app.staticTexts["Hello from UI tests"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Stub reply to: Hello from UI tests"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(clearButton.isEnabled)
    }

    @MainActor
    func testStopGenerationKeepsPartialAssistantReply() throws {
        let app = launchApplication()
        let inputField = app.textFields["Message Input"]
        let finalReply = "Stub reply to: Please stream a longer response so the stop button can interrupt it"

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Please stream a longer response so the stop button can interrupt it")
        app.buttons["Send Message"].click()

        let stopButton = app.buttons["Stop Generation"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        sleep(1)
        stopButton.click()

        XCTAssertTrue(app.buttons["Send Message"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[finalReply].exists)
        XCTAssertTrue(app.staticTexts["Assistant"].exists)
    }

    @MainActor
    func testClearChatRestoresEmptyState() throws {
        let app = launchApplication()
        let inputField = app.textFields["Message Input"]
        let clearButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Clear this conversation")
        app.buttons["Send Message"].click()

        XCTAssertTrue(app.staticTexts["Stub reply to: Clear this conversation"].waitForExistence(timeout: 10))
        XCTAssertTrue(clearButton.isEnabled)

        clearButton.click()

        XCTAssertTrue(app.staticTexts["Start a conversation"].waitForExistence(timeout: 5))
        XCTAssertFalse(clearButton.isEnabled)
        XCTAssertFalse(app.staticTexts["Clear this conversation"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            launchApplication().terminate()
        }
    }

    @MainActor
    private func launchApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }
}
