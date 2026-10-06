//
//  SeaBattleUITests.swift
//  SeaBattleUITests
//
//  Created by Ivan Tkachev on 05/02/2025.
//
//  R4.6: the three tests that drove the pre-redesign main screen are gone with
//  that screen. These go through the new interface instead: the menu, and a
//  single-player match from the menu to the first shot and back.
//
//  The app starts past onboarding, in English, with the level step and
//  without sound — set through launch arguments, which override what the app
//  stored in `UserDefaults` for this run only.
//

import XCTest

final class SeaBattleUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `XCUIApplication` is main-actor isolated, so the launch lives here and
    /// not in the nonisolated `setUpWithError`.
    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launchArguments += [
            "-notFirstLaunch", "YES",
            "-onboardingDone", "YES",
            "-Language", "en",
            "-askLevelBeforeMatch", "YES",
            "-soundOn", "NO",
            "-musicOn", "NO",
        ]
        app.launch()
    }

    @MainActor
    func testMenuShowsTheTitleTabsAndModes() throws {
        launch()
        XCTAssertTrue(app.staticTexts["titleMainText"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["titleMainText"].label, "Sea Battle")

        // The three tabs live on the iPhone only; the iPad has corner squares.
        if UIDevice.current.userInterfaceIdiom == .phone {
            for tab in ["play", "statistics", "settings"] {
                XCTAssertTrue(app.buttons["tab_\(tab)"].exists, "Tab \(tab) is missing")
            }
        }
        for mode in ["Single player", "Paper game", "Two players on one device",
                     "Nearby, no internet", "Online"] {
            XCTAssertTrue(modeButton(mode).exists, "Mode \(mode) is missing")
        }
    }

    @MainActor
    func testASinglePlayerMatchStartsTakesAShotAndLeaves() throws {
        launch()
        XCTAssertTrue(app.staticTexts["titleMainText"].waitForExistence(timeout: 5))
        modeButton("Single player").tap()

        let medium = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Medium")).firstMatch
        XCTAssertTrue(medium.waitForExistence(timeout: 5))
        medium.tap()
        app.buttons["Start match"].tap()

        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // A miss passes the turn to the computer and a hit keeps it, so after
        // one shot the cell is no longer fresh either way.
        // Only the opponent's board is tappable, so only its cells are buttons.
        let cell = app.buttons["A1"].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.buttons["navMenuButton"].waitForExistence(timeout: 5))

        app.buttons["navMenuButton"].tap()
        let leave = app.buttons["modalSecondary"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()

        XCTAssertTrue(app.staticTexts["titleMainText"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["continueGameButton"].exists,
                      "A match left halfway can be continued from the menu")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    /// A menu row is one button whose label starts with the mode's title.
    @MainActor
    private func modeButton(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }
}
