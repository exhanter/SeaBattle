//
//  SeaBattleUITests.swift
//  SeaBattleUITests
//
//  Created by Ivan Tkachev on 05/02/2025.
//

import XCTest

final class SeaBattleUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        app = nil
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLocalization() throws {
        let text = app.staticTexts["titleMainText"]
        let language = Locale.current.identifier
        
        if language == "EN" {
            XCTAssertEqual(text.label, "Sea Battle", "Localization test for EN failed")
        } else if language == "NL" {
            XCTAssertEqual(text.label, "Zeeslag", "Localization test for NL failed")
        }
    }
    
    @MainActor
    func testSideButtonsDisabledBeforeStart() throws {
        let sideMenuButton = app.buttons["sideMenuButton"]
        let sidePlayerButton = app.buttons["sidePlayerButton"]
        let sideEnemyButton = app.buttons["sideEnemyButton"]
        let sideAboutButton = app.buttons["sideAboutButton"]
        
        //app.buttons["newOrStopGameButton"].tap()
        
        XCTAssertTrue(sideMenuButton.isEnabled, "The side Menu button should be disabled")
        XCTAssertFalse(sidePlayerButton.isEnabled, "The side Player button should be disabled")
        XCTAssertFalse(sideEnemyButton.isEnabled, "The side Enemy button should be disabled")
        XCTAssertTrue(sideAboutButton.isEnabled, "The side About button should be disabled")
    }
    
    @MainActor
    func testButtonsDisabledWhileShipsReplacement() throws {
        let startOrYourTurnButton = app.buttons["startOrYourTurnButton"]
        let sideMenuButton = app.buttons["sideMenuButton"]
        let sidePlayerButton = app.buttons["sidePlayerButton"]
        let sideEnemyButton = app.buttons["sideEnemyButton"]
        let sideAboutButton = app.buttons["sideAboutButton"]
        
        app.buttons["newOrStopGameButton"].tap()
        app.buttons["changeOrSaveButton"].tap()
        
        XCTAssertFalse(startOrYourTurnButton.isEnabled, "The Start / YourTurn button should be disabled")
        XCTAssertFalse(sideMenuButton.isEnabled, "The side Menu button should be disabled")
        XCTAssertFalse(sidePlayerButton.isEnabled, "The side Player button should be disabled")
        XCTAssertFalse(sideEnemyButton.isEnabled, "The side Enemy button should be disabled")
        XCTAssertFalse(sideAboutButton.isEnabled, "The side About button should be disabled")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
