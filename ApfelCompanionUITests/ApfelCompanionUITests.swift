import XCTest

final class ApfelCompanionUITests: XCTestCase {
    private var settingsFilePath: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        settingsFilePath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
            .path
        try? FileManager.default.removeItem(atPath: settingsFilePath)
    }

    override func tearDownWithError() throws {
        if let settingsFilePath {
            try? FileManager.default.removeItem(atPath: settingsFilePath)
        }
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
    func testSettingsWindowEditsAllControls() throws {
        let app = launchApplication()

        openSettings(in: app)

        let systemPrompt = app.descendants(matching: .any)
            .matching(identifier: "settings.systemPrompt")
            .firstMatch
        let temperatureToggle = app.descendants(matching: .any)
            .matching(identifier: "settings.temperature.toggle")
            .firstMatch
        let temperatureSlider = app.descendants(matching: .any)
            .matching(identifier: "settings.temperature.slider")
            .firstMatch
        let temperatureValue = app.descendants(matching: .any)
            .matching(identifier: "settings.temperature.value")
            .firstMatch
        let maxTokensToggle = app.descendants(matching: .any)
            .matching(identifier: "settings.maxTokens.toggle")
            .firstMatch
        let maxTokensField = app.descendants(matching: .any)
            .matching(identifier: "settings.maxTokens.field")
            .firstMatch

        XCTAssertTrue(systemPrompt.waitForExistence(timeout: 5))

        replaceText(in: systemPrompt, with: "UI test system prompt")

        XCTAssertTrue(temperatureToggle.waitForExistence(timeout: 5))
        temperatureToggle.click()
        XCTAssertTrue(temperatureSlider.waitForExistence(timeout: 5))
        temperatureSlider.adjust(toNormalizedSliderPosition: 0.75)
        XCTAssertTrue(temperatureValue.waitForExistence(timeout: 5))

        XCTAssertTrue(maxTokensToggle.waitForExistence(timeout: 5))
        maxTokensToggle.click()
        XCTAssertTrue(maxTokensField.waitForExistence(timeout: 5))
        replaceText(in: maxTokensField, with: "4096")

        XCTAssertEqual(systemPrompt.value as? String, "UI test system prompt")
        XCTAssertTrue(maxTokensField.exists)

        let settings = try loadSettingsFromDisk()
        XCTAssertEqual(settings.systemPrompt, "UI test system prompt")
        XCTAssertEqual(settings.temperature ?? -1, 1.5, accuracy: 0.05)
        XCTAssertEqual(settings.maxTokens, 4096)
    }

    @MainActor
    func testSettingsPersistAcrossRelaunch() throws {
        let firstLaunch = launchApplication()
        openSettings(in: firstLaunch)

        let systemPrompt = firstLaunch.descendants(matching: .any)
            .matching(identifier: "settings.systemPrompt")
            .firstMatch
        let temperatureToggle = firstLaunch.descendants(matching: .any)
            .matching(identifier: "settings.temperature.toggle")
            .firstMatch
        let temperatureSlider = firstLaunch.descendants(matching: .any)
            .matching(identifier: "settings.temperature.slider")
            .firstMatch
        let maxTokensToggle = firstLaunch.descendants(matching: .any)
            .matching(identifier: "settings.maxTokens.toggle")
            .firstMatch
        let maxTokensField = firstLaunch.descendants(matching: .any)
            .matching(identifier: "settings.maxTokens.field")
            .firstMatch

        XCTAssertTrue(systemPrompt.waitForExistence(timeout: 5))
        replaceText(in: systemPrompt, with: "Persist me")
        temperatureToggle.click()
        XCTAssertTrue(temperatureSlider.waitForExistence(timeout: 5))
        temperatureSlider.adjust(toNormalizedSliderPosition: 0.25)
        maxTokensToggle.click()
        XCTAssertTrue(maxTokensField.waitForExistence(timeout: 5))
        replaceText(in: maxTokensField, with: "1536")

        firstLaunch.terminate()

        let savedSettings = try loadSettingsFromDisk()
        XCTAssertEqual(savedSettings.systemPrompt, "Persist me")
        XCTAssertEqual(savedSettings.temperature ?? -1, 0.5, accuracy: 0.05)
        XCTAssertEqual(savedSettings.maxTokens, 1536)

        let secondLaunch = launchApplication()
        openSettings(in: secondLaunch)

        let restoredSystemPrompt = secondLaunch.descendants(matching: .any)
            .matching(identifier: "settings.systemPrompt")
            .firstMatch
        let restoredTemperatureSlider = secondLaunch.descendants(matching: .any)
            .matching(identifier: "settings.temperature.slider")
            .firstMatch
        let restoredTemperatureValue = secondLaunch.descendants(matching: .any)
            .matching(identifier: "settings.temperature.value")
            .firstMatch
        let restoredMaxTokensField = secondLaunch.descendants(matching: .any)
            .matching(identifier: "settings.maxTokens.field")
            .firstMatch

        XCTAssertTrue(restoredSystemPrompt.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredSystemPrompt.value as? String, "Persist me")
        XCTAssertTrue(restoredTemperatureSlider.waitForExistence(timeout: 5))
        XCTAssertTrue(restoredTemperatureValue.waitForExistence(timeout: 5))
        XCTAssertTrue(restoredMaxTokensField.waitForExistence(timeout: 5))
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
        app.launchEnvironment["APFEL_UI_TEST_SETTINGS_PATH"] = settingsFilePath
        app.launch()
        return app
    }

    @MainActor
    private func messageInput(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "chat.input").firstMatch
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: [.command])
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with text: String) {
        element.click()
        element.typeKey("a", modifierFlags: [.command])
        element.typeText(text)
    }

    private func loadSettingsFromDisk() throws -> UITestSettingsSnapshot {
        let data = try Data(contentsOf: URL(fileURLWithPath: settingsFilePath))
        return try JSONDecoder().decode(UITestSettingsSnapshot.self, from: data)
    }
}

private struct UITestSettingsSnapshot: Decodable {
    let systemPrompt: String
    let temperature: Double?
    let maxTokens: Int?
}
