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
        let ship = Ship(number: 2, orientation: .vertical, numberOfDecks: 3, coordinates: [(8, 10), (9, 10), (10, 10)])
        self.ships = [ship]
    }
}

@MainActor
final class SeaBattleTests: XCTestCase {
    
    var sut: GameLogicViewModel!
    var sutReal: GameLogicViewModel!
    var appState: AppState!
    var player: PlayerData!
    var enemy: PlayerData!
    var testPlayer: PlayerDataMock!
    var testEnemy: PlayerDataMock!

    override func setUpWithError() throws {
        try super.setUpWithError()
        appState = AppState()
        testPlayer = PlayerDataMock(name: "TestPlayer")
        testEnemy = PlayerDataMock(name: "TestEnemy")
        player = PlayerData(name: "Player")
        enemy = PlayerData(name: "Enemy")
        sut = GameLogicViewModel()
        sut.configure(appState: appState, enemy: testEnemy, player: testPlayer)
        sutReal = GameLogicViewModel()
        sutReal.configure(appState: appState, enemy: enemy, player: player)
    }

    override func tearDownWithError() throws {
        testEnemy = nil
        testPlayer = nil
        player = nil
        enemy = nil
        appState = nil
        sut = nil
        try super.tearDownWithError()
    }
    
    func testCheckShipOnFire() throws {
        // prepare
        let row = 9
        let column = 10
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
        //prepare
        let target = testPlayer
        target?.shipsRandomArrangement()
        let ship = target?.ships[0]
        for coordinate in ship!.coordinates {
            let row = coordinate.0
            let column = coordinate.1
            target?.cells[row - 1][column - 1].cellStatus = .onFire
        }
        
        //use
        let result = sut.checkShipIsTotallyDestroyed(ship: ship!, target: target!)
        
        //check
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
    
    func testFindAvailableCellsDoesNotHangWhenPriorityCellsUnavailable() {
        // Regression: previously a priority list made up entirely of unavailable
        // (or out-of-bounds) cells made findAvailableCellsForFire spin forever.
        player.cells[4][4].isAvailable = false // cell (5, 5)
        player.cells[4][5].isAvailable = false // cell (5, 6)
        appState.potentialCellsForFinishingDamagedShip = [(5, 5), (5, 6), (11, 5)]

        //use
        let cell = sutReal.findAvailableCellsForFire()

        //check
        XCTAssertTrue((1...10).contains(cell.0) && (1...10).contains(cell.1), "Returned cell must be within the field")
        XCTAssertTrue(player.cells[cell.0 - 1][cell.1 - 1].isAvailable, "Returned cell must be available")
    }

    func testWholeTheSequenceOfComputerTurns() {
        // the test was made in attepmt to catch endless loop
        //prepare
        player.shipsRandomArrangement()
        
        //use
        repeat {
            sutReal.computerTurn()
        } while player.numberShipsDestroyed < 10
        
        //check
        XCTAssertEqual(player.numberShipsDestroyed, 10)
    }
}
