//
//  SeaBattleTests.swift
//  SeaBattleTests
//
//  Created by Ivan Tkachev on 31/01/2025.
//

import XCTest
@testable import SeaBattle

class PlayerDataMock: PlayerData {
    var shipsRandomArrangementCalled = false
    override func shipsRandomArrangement() {
        self.shipsRandomArrangementCalled = true
        let ship1 = Ship(number: 0, orientation: .horizontal, numberOfDecks: 4, coordinates: [(3, 1), (3, 2), (3, 3), (3, 4)])
        let ship2 = Ship(number: 1, orientation: .both, numberOfDecks: 4, coordinates: [(5, 5)])
        let ship3 = Ship(number: 2, orientation: .vertical, numberOfDecks: 3, coordinates: [(8, 10), (9, 10), (10, 10)])
        self.ships = [ship1, ship2, ship3]
    }
}

final class SeaBattleTests: XCTestCase {
    
    var sut: GameLogicViewModel!
    var appState: AppState!
    var testPlayer: PlayerDataMock!
    var testEnemy: PlayerDataMock!

    override func setUpWithError() throws {
        try super.setUpWithError()
        appState = AppState(tempInstance: true)
        testPlayer = PlayerDataMock(name: "TestPlayer")
        testEnemy = PlayerDataMock(name: "TestEnemy")
        sut = GameLogicViewModel(appState: appState, enemy: testEnemy, player: testPlayer)
    }

    override func tearDownWithError() throws {
        testEnemy = nil
        testPlayer = nil
        appState = nil
        sut = nil
        try super.tearDownWithError()
    }
    
    func testCheckShipOnFire() throws {
        // prepare
        let row = 3
        let column = 3
        let target = testPlayer
        
        // use
        target?.shipsRandomArrangement()
        sut.checkShipOnFire(row: row, column: column, target: target!)
        
        // check
        XCTAssertEqual(target?.cells[1][1].cellStatus, .unknown, "The cell should be unknown")
        XCTAssertEqual(target?.ships.count, 1, "Number of arranged ships should be 1")
        XCTAssertEqual(target?.cells[row - 1][column - 1].cellStatus, .onFire, "The cell should be on fire")
        XCTAssertTrue(target?.shipsRandomArrangementCalled ?? false, "The method shipsRandomArrangement should be called")
    }
    
    func testCheckShipIsTotallyDestroyed() throws {
        let target = testPlayer
        target?.shipsRandomArrangement()
        let ship = target?.ships[2]
        for coordinate in ship!.coordinates {
            let row = coordinate.0
            let column = coordinate.1
            target?.cells[row - 1][column - 1].cellStatus = .onFire
        }
        
        let result = sut.checkShipIsTotallyDestroyed(ship: ship!, target: target!)
        
        XCTAssertTrue(result, "The ship should be destroyed")
        XCTAssertTrue(target?.shipsRandomArrangementCalled ?? false, "The method shipsRandomArrangement should be called")
    }
    
    func testDefinePriorityTargetCells() {
        //prepare
        var arrayOfCells: [(Int, Int)] = []
        let expectedArrayOfCells: [(Int, Int)] = [(9, 10), (10, 9)]
        
        //use
        arrayOfCells = sut.definePriorityTargetCells(row: 10, column: 10)!
        
        //check
        for i in 0 ..< expectedArrayOfCells.count {
            XCTAssertEqual(arrayOfCells[i].0, expectedArrayOfCells[i].0, "Arrays are not equal")
            XCTAssertEqual(arrayOfCells[i].1, expectedArrayOfCells[i].1, "Arrays are not equal")
        }
    }
    
    func testFindAvailableCellsForFire() {
        //prepare
        var cell: (Int, Int)
        appState.potentialCellsForFinishingDamagedShip = [(1, 2), (3, 2), (2, 1)]
        let array = appState.potentialCellsForFinishingDamagedShip!
        
        //use
        cell = sut.findAvailableCellsForFire()
        
        //check
        XCTAssertTrue(array.contains(where: { $0 == cell }), "The method works incorrectly")
    }

}
