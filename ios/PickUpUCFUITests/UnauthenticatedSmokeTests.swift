import XCTest

final class UnauthenticatedSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(largestType: Bool = false) throws -> XCUIApplication {
        #if !DEBUG || !targetEnvironment(simulator)
        throw XCTSkip("UI smoke requires a Debug simulator; do not launch the normal app")
        #endif
        let app = XCUIApplication()
        // This single argument must activate every isolation guard in the app.
        app.launchEnvironment.removeValue(forKey: "PICKUP_UNIT_TESTS")
        app.launchArguments = ["--pickup-ui-smoke"]
        if largestType {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let marker = app.otherElements["ui-smoke-isolated"]
        XCTAssertTrue(marker.waitForExistence(timeout: 10), "Never interact without verified isolation")
        if largestType { XCTAssertEqual(marker.value as? String, "accessibility5") }
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testIntroAndRelaunchStartDeterministically() throws {
        let app = try launch()
        XCTAssertTrue(app.buttons["welcome-continue"].exists)
        tap(app.buttons["welcome-continue"], in: app)
        tap(app.buttons["welcome-continue"], in: app)
        tap(app.buttons["welcome-sign-up"], in: app)
        XCTAssertTrue(app.textFields["Display name"].waitForExistence(timeout: 5))
        attach(app, name: "Create account after intro")
        app.terminate()
        let relaunched = try launch()
        XCTAssertTrue(relaunched.buttons["welcome-continue"].exists)
    }

    func testAccountSwitchCarriesEmailAndReplacesRoute() throws {
        let app = try launch()
        tap(app.buttons["welcome-sign-in"], in: app)
        let email = app.textFields["UCF email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("ui-smoke@ucf.edu")
        tap(app.buttons["Done"], in: app)
        tap(app.buttons["sign-in-switch-to-sign-up"], in: app)
        XCTAssertTrue(app.textFields["Display name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["UCF email"].value as? String, "ui-smoke@ucf.edu")
        tap(app.buttons["sign-up-switch-to-sign-in"], in: app)
        XCTAssertTrue(app.secureTextFields["Password"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Display name"].exists)
        XCTAssertEqual(app.textFields["UCF email"].value as? String, "ui-smoke@ucf.edu")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["welcome-sign-in"].waitForExistence(timeout: 5), "Switch must replace the account route, not stack forms")
    }

    func testBlankSignInShowsLocalValidation() throws {
        let app = try launch()
        tap(app.buttons["welcome-sign-in"], in: app)
        tap(app.buttons["Sign In"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Password is required"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Error: Email is required"].exists)
        attach(app, name: "Blank sign in validation")
    }

    func testBlankSignUpShowsLocalValidation() throws {
        let app = try launch()
        tap(app.buttons["welcome-sign-in"], in: app)
        tap(app.buttons["sign-in-switch-to-sign-up"], in: app)
        XCTAssertTrue(app.textFields["Display name"].waitForExistence(timeout: 5))
        tap(app.buttons["Create account"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Display name is required"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Error: Email is required"].exists)
        XCTAssertTrue(app.staticTexts["Error: Password must be at least 8 characters"].exists)
        XCTAssertTrue(app.secureTextFields["Confirm password"].exists)
        attach(app, name: "Blank sign up validation")
    }

    func testPasswordResetLocalValidationAndReturnToSignIn() throws {
        let app = try launch()
        tap(app.buttons["welcome-sign-in"], in: app)
        tap(app.buttons["Forgot password?"], in: app)
        tap(app.buttons["Send reset link"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Email is required"].waitForExistence(timeout: 5))
        attach(app, name: "Blank reset request validation")
        let email = app.textFields["UCF email"]
        tap(email, in: app)
        email.typeText("ui-smoke@example.com")
        tap(app.buttons["Done"], in: app)
        tap(app.buttons["Send reset link"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Use your @knights.ucf.edu or @ucf.edu email"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["If an account exists for this email, we sent a password reset link."].exists)
        attach(app, name: "Non school reset request validation")
        tap(app.buttons["reset-back-to-sign-in"], in: app)
        XCTAssertTrue(app.secureTextFields["Password"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["UCF email"].value as? String, "UCF email", "Returning must preserve the original empty sign-in field")
        XCTAssertTrue(app.buttons["sign-in-switch-to-sign-up"].exists)
    }

    func testLargestDynamicTypeWelcomeAndAccountNavigation() throws {
        let app = try launch(largestType: true)
        attach(app, name: "Largest Dynamic Type welcome")
        tap(app.buttons["welcome-sign-in"], in: app)
        tap(app.buttons["Sign In"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Password is required"].waitForExistence(timeout: 5))
        attach(app, name: "Largest Dynamic Type sign in validation")
        tap(app.buttons["sign-in-switch-to-sign-up"], in: app)
        XCTAssertTrue(app.textFields["Display name"].waitForExistence(timeout: 5))
        tap(app.buttons["sign-up-switch-to-sign-in"], in: app)
        let accountFormGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.textFields["Display name"])
        wait(for: [accountFormGone], timeout: 5)
        XCTAssertTrue(app.buttons["sign-in-switch-to-sign-up"].exists)
        attach(app, name: "Largest Dynamic Type account switch")
    }
}
