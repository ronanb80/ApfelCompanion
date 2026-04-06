import XCTest

final class ApfelCompanionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsReadyStateAndEmptyConversation() throws {
        let app = launchApplication()
        let inputField = messageInput(in: app)
        let trashButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch
        let sidebar = app.splitGroups.descendants(matching: .any).matching(identifier: "chat.sidebar").firstMatch

        XCTAssertTrue(app.staticTexts["Start a conversation"].waitForExistence(timeout: 5))
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        XCTAssertFalse(trashButton.isEnabled)
    }

    @MainActor
    func testSendMessageStreamsAssistantReply() throws {
        let app = launchApplication()
        let inputField = messageInput(in: app)
        let trashButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Hello from UI tests")
        app.buttons["Send Message"].click()

        XCTAssertTrue(app.staticTexts["Hello from UI tests"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Stub reply to: Hello from UI tests"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(trashButton.isEnabled)
    }

    @MainActor
    func testStopGenerationKeepsPartialAssistantReply() throws {
        let app = launchApplication()
        let inputField = messageInput(in: app)
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
        let inputField = messageInput(in: app)
        let trashButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Clear this conversation")
        app.buttons["Send Message"].click()

        XCTAssertTrue(app.staticTexts["Stub reply to: Clear this conversation"].waitForExistence(timeout: 10))
        XCTAssertTrue(trashButton.isEnabled)

        trashButton.click()

        XCTAssertTrue(app.staticTexts["Start a conversation"].waitForExistence(timeout: 5))
        XCTAssertFalse(trashButton.isEnabled)
        XCTAssertFalse(app.staticTexts["Clear this conversation"].exists)
    }

    @MainActor
    func testCreateNewChatShowsFreshConversation() throws {
        let app = launchApplication()
        let inputField = messageInput(in: app)
        let newChatButton = app.descendants(matching: .button).matching(identifier: "chat.new").firstMatch
        let trashButton = app.descendants(matching: .button).matching(identifier: "chat.clear").firstMatch

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("First chat")
        app.buttons["Send Message"].click()

        XCTAssertTrue(app.staticTexts["Stub reply to: First chat"].waitForExistence(timeout: 10))

        newChatButton.click()

        XCTAssertTrue(app.staticTexts["Start a conversation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Stub reply to: First chat"].exists)
        XCTAssertTrue(trashButton.isEnabled)
    }

    @MainActor
    func testShiftReturnAddsNewlineBeforeSending() throws {
        let app = launchApplication()
        let inputField = messageInput(in: app)

        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("First line")
        inputField.typeKey(.return, modifierFlags: [.shift])
        inputField.typeText("Second line")
        inputField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["First line\nSecond line"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Stub reply to: First line\nSecond line"].waitForExistence(timeout: 10)
        )
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

    @MainActor
    private func messageInput(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "chat.input").firstMatch
    }
}
