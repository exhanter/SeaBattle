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
    func testAlghoritmWithPressingButtonsConsistently() throws {
        var endGame = false
        let testCell: XCUIElement = app.buttons["testCell"]

        app.buttons["newOrStopGameButton"].tap()
        app.buttons["startOrYourTurnButton"].tap()
        repeat {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: app.buttons["testCell"])
            let result = XCTWaiter().wait(for: [expectation], timeout: 30.0) // max 30 seconds
            if result == .completed {
                testCell.tap()
            } else {
                XCTFail("The cell button didn't become enabled in 30 seconds")
            }
            
            let winAlert = app.otherElements["winAlert"]
//            let endGameExpectation = XCTNSPredicateExpectation(
//                    predicate: NSPredicate(format: "exists == true"),
//                    object: app.otherElements["winAlert"]
//                )
//            let endResult = XCTWaiter().wait(for: [endGameExpectation], timeout: 10)
            
            let yourTurnExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: app.buttons["startOrYourTurnButton"])
            let yourTurnButtonResult = XCTWaiter().wait(for: [yourTurnExpectation], timeout: 10.0)
            if yourTurnButtonResult == .completed {
                app.buttons["startOrYourTurnButton"].tap()
            } else if winAlert.exists {
                print("FINISHED GAME")
                endGame = true
            } else {
                XCTFail("The Your Turn button didn't become enabled in 30 seconds")
            }
            
        } while !endGame
        XCTAssertTrue(endGame, "The game should be finished")
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
