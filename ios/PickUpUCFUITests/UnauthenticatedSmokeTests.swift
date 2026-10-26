import XCTest

final class UnauthenticatedSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(largestType: Bool = false, authenticated: Bool = false) throws -> XCUIApplication {
        #if !DEBUG || !targetEnvironment(simulator)
        throw XCTSkip("UI smoke requires a Debug simulator; do not launch the normal app")
        #endif
        let app = XCUIApplication()
        // This single argument must activate every isolation guard in the app.
        app.launchEnvironment.removeValue(forKey: "PICKUP_UNIT_TESTS")
        app.launchArguments = [authenticated ? "--pickup-ui-smoke-authenticated" : "--pickup-ui-smoke"]
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

    func testAuthenticatedTabsReadSyntheticDataAndRelaunch() throws {
        let app = try launch(authenticated: true)
        XCTAssertTrue(app.buttons["session-open-00000000-0000-0000-0000-000000000021"].waitForExistence(timeout: 10))
        attach(app, name: "Synthetic Discover")
        tap(app.tabBars.buttons["My Games"], in: app)
        XCTAssertTrue(app.buttons["session-open-00000000-0000-0000-0000-000000000021"].waitForExistence(timeout: 10))
        tap(app.buttons.containing(.staticText, identifier: "Past games").firstMatch, in: app)
        XCTAssertTrue(app.buttons["session-open-00000000-0000-0000-0000-000000000022"].waitForExistence(timeout: 10))
        attach(app, name: "Synthetic My Games history")
        tap(app.tabBars.buttons["Profile"], in: app)
        XCTAssertTrue(app.staticTexts["UI Smoke Student"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["profile-stat-games"].exists)
        XCTAssertTrue(app.buttons["profile-stat-games"].label.contains("7"))
        attach(app, name: "Synthetic Profile")
        app.terminate()
        let relaunched = try launch(authenticated: true)
        XCTAssertTrue(relaunched.buttons["session-open-00000000-0000-0000-0000-000000000021"].waitForExistence(timeout: 10))
        let original = try launch()
        XCTAssertTrue(original.buttons["welcome-continue"].exists)
        XCTAssertFalse(original.tabBars.buttons["Profile"].exists)
    }

    func testAuthenticatedCreateDraftValidationBackAndDiscard() throws {
        let app = try launch(authenticated: true)
        tap(app.tabBars.buttons["Create"], in: app)
        XCTAssertTrue(app.navigationBars["Create session"].waitForExistence(timeout: 5))
        // Discover's filter has the same label behind the sheet; scope to this step.
        let sportStep = app.scrollViews.containing(.staticText, identifier: "What are you playing?").firstMatch
        tap(sportStep.buttons["Other"], in: app)
        tap(app.buttons["Next"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Enter a sport name (e.g. pickleball)."].waitForExistence(timeout: 5))
        let errorVisible = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                app.staticTexts["Error: Enter a sport name (e.g. pickleball)."].isHittable
            }, object: nil)
        wait(for: [errorVisible], timeout: 5)
        attach(app, name: "Create draft empty sport validation")

        let sportName = app.textFields["Sport name"]
        tap(sportName, in: app)
        sportName.typeText("Smoke badminton")
        tap(app.buttons["Done"], in: app)
        tap(app.buttons["In 2 hours"], in: app)
        tap(app.buttons["Next"], in: app)
        XCTAssertTrue(app.staticTexts["No campus venues are available. Choose a custom location below."].waitForExistence(timeout: 5))
        tap(app.buttons["Next"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Search on the map and choose where you're playing."].waitForExistence(timeout: 5))
        attach(app, name: "Create draft missing location validation")

        tap(app.buttons["Back"], in: app)
        XCTAssertTrue(sportName.waitForExistence(timeout: 5))
        XCTAssertEqual(sportName.value as? String, "Smoke badminton")
        tap(app.navigationBars["Create session"].buttons["Close"], in: app)
        XCTAssertTrue(app.buttons["Discard"].waitForExistence(timeout: 5))
        attach(app, name: "Create draft discard confirmation")
        // This iOS popover omits the cancel-role button; tapping outside cancels.
        // The field is intentionally blocked by the modal, so use its visible
        // position as an outside-popover tap rather than asking XCTest to hit it.
        sportName.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirmationGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons["Discard"])
        wait(for: [confirmationGone], timeout: 5)
        XCTAssertTrue(sportName.waitForExistence(timeout: 5))
        XCTAssertEqual(sportName.value as? String, "Smoke badminton")
        tap(app.navigationBars["Create session"].buttons["Close"], in: app)
        tap(app.buttons["Discard"], in: app)
        XCTAssertTrue(app.buttons["session-open-00000000-0000-0000-0000-000000000021"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Create session"].exists)

        tap(app.tabBars.buttons["Create"], in: app)
        XCTAssertTrue(app.navigationBars["Create session"].waitForExistence(timeout: 5))
        tap(sportStep.buttons["Other"], in: app)
        XCTAssertTrue(sportName.waitForExistence(timeout: 5))
        XCTAssertEqual(sportName.value as? String, "Sport name", "Discard must remove the unsaved sport name")
        attach(app, name: "Create draft reopened without discarded name")
        tap(app.navigationBars["Create session"].buttons["Close"], in: app)
        tap(app.buttons["Discard"], in: app)
    }

    func testLargestDynamicTypeCreateValidationRevealsSportNameError() throws {
        let app = try launch(largestType: true, authenticated: true)
        tap(app.tabBars.buttons["Create"], in: app)
        XCTAssertTrue(app.navigationBars["Create session"].waitForExistence(timeout: 5))
        let sportStep = app.scrollViews.containing(.staticText, identifier: "What are you playing?").firstMatch
        tap(sportStep.buttons["Other"], in: app)
        tap(app.buttons["Next"], in: app)
        let error = app.staticTexts["Error: Enter a sport name (e.g. pickleball)."]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        let errorVisible = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in error.isHittable }, object: nil)
        wait(for: [errorVisible], timeout: 5)
        attach(app, name: "Largest Dynamic Type visible create validation")
        tap(app.navigationBars["Create session"].buttons["Close"], in: app)
        tap(app.buttons["Discard"], in: app)
    }

    func testAuthenticatedAccountFormsRejectInvalidInputsAndResetOnReturn() throws {
        let app = try launch(authenticated: true)
        tap(app.tabBars.buttons["Profile"], in: app)
        tap(app.buttons.containing(.staticText, identifier: "Settings").firstMatch, in: app)
        tap(app.buttons.containing(.staticText, identifier: "Change password").firstMatch, in: app)
        let currentPassword = app.secureTextFields["Current password"]
        XCTAssertTrue(currentPassword.waitForExistence(timeout: 5))
        XCTAssertEqual(currentPassword.value as? String, "Current password")
        tap(app.buttons["Update password"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Current password is required"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Error: Password must be at least 8 characters"].exists)
        attach(app, name: "Account blank password validation")

        tap(app.secureTextFields["New password"], in: app)
        app.secureTextFields["New password"].typeText("short")
        tap(app.secureTextFields["Confirm new password"], in: app)
        app.secureTextFields["Confirm new password"].typeText("different")
        tap(app.buttons["Done"], in: app)
        // Keep current empty: this path must stay in local validation.
        XCTAssertEqual(currentPassword.value as? String, "Current password")
        tap(app.buttons["Update password"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Passwords do not match"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Error: Current password is required"].exists)
        XCTAssertTrue(app.staticTexts["Error: Password must be at least 8 characters"].exists)
        XCTAssertFalse(app.staticTexts["Password updated successfully."].exists)
        attach(app, name: "Account short and mismatched password validation")
        app.navigationBars["Change password"].buttons.firstMatch.tap()
        let passwordFormGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons["Update password"])
        wait(for: [passwordFormGone], timeout: 5)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        tap(app.buttons.containing(.staticText, identifier: "Change password").firstMatch, in: app)
        XCTAssertTrue(currentPassword.waitForExistence(timeout: 5))
        XCTAssertEqual(currentPassword.value as? String, "Current password")
        tap(app.buttons["Update password"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Current password is required"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Error: Passwords do not match"].exists,
                       "Reopened empty fields must not validate the abandoned mismatched draft")
        let reopenedPasswordsEmpty = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                currentPassword.value as? String == "Current password"
                    && app.secureTextFields["New password"].value as? String == "New password"
                    && app.secureTextFields["Confirm new password"].value as? String == "Confirm new password"
            }, object: nil)
        wait(for: [reopenedPasswordsEmpty], timeout: 5)
        app.navigationBars["Change password"].buttons.firstMatch.tap()

        tap(app.buttons.containing(.staticText, identifier: "Edit username").firstMatch, in: app)
        let username = app.textFields["Username"]
        let existingUsername = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ui_smoke"), object: username)
        wait(for: [existingUsername], timeout: 5)
        tap(username, in: app)
        username.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "ui_smoke".count))
        tap(app.buttons["Done"], in: app)
        XCTAssertEqual(username.value as? String, "Username")
        tap(app.buttons["Save"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Username is required"].waitForExistence(timeout: 5))
        tap(username, in: app)
        username.typeText("bad!name")
        tap(app.buttons["Done"], in: app)
        XCTAssertEqual(username.value as? String, "bad!name", "Never submit a valid username in this smoke path")
        tap(app.buttons["Save"], in: app)
        XCTAssertTrue(app.staticTexts["Error: Use 3–20 characters: letters, numbers, underscore"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Username saved."].exists)
        attach(app, name: "Account invalid username validation")
        app.navigationBars["Username"].buttons.firstMatch.tap()
        tap(app.buttons.containing(.staticText, identifier: "Edit username").firstMatch, in: app)
        let unchangedUsername = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ui_smoke"), object: username)
        wait(for: [unchangedUsername], timeout: 5)
        XCTAssertFalse(app.staticTexts["Username saved."].exists)
        attach(app, name: "Account username unchanged after invalid draft")
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
