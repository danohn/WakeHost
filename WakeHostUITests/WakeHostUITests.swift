//
//  WakeHostUITests.swift
//  WakeHostUITests
//
//  Created by Daniel on 12/3/2026.
//

import XCTest

final class WakeHostUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAppearsOnFirstLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-force-onboarding")
        app.launch()

        XCTAssertTrue(app.staticTexts["Set Up WakeHost"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Enter your OPNsense connection details to get started."].exists)
        XCTAssertTrue(app.secureTextFields["API Key"].exists)
        XCTAssertTrue(app.secureTextFields["API Secret"].exists)
        XCTAssertTrue(app.textFields["Address"].exists)
        XCTAssertTrue(app.textFields["Port"].exists)
        XCTAssertTrue(app.buttons["Finish Setup"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
