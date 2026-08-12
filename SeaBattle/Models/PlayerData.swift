//
//  Data.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import SwiftUI
import AVFoundation
import Observation

@Observable
class PlayerData {

    let name: String
    var cells = [[Cell]]()
    var ships = [Ship]()
    var showFinishGameAlert = false
    var shipsDestroyed: [Ship] {
        return ships.filter{ $0.isDestroyed }
    }
    var numberShipsDestroyed: Int {
        return shipsDestroyed.count
    }

    var shipPositions: [CGPoint] = Array(repeating: .zero, count: 10)
    var shipIsDragging: [Bool] = Array(repeating: false, count: 10)
    var fireStrokeArray = [[Bool]]()
    
    ///Method creates and arranges ships on the field.
    /// Ships are placed in a RANDOM order each layout (not always largest-first)
    /// with a whole-board restart if a ship can't fit. Fixed largest-first order
    /// made the leftover free cells cluster at the edges, so single-deck ships
    /// ended up on the perimeter and became predictable. Randomizing the order
    /// spreads them out. The final `ships` array is still returned in canonical
    /// order (by `number`) so the manual-arrangement UI mapping stays stable.
    func shipsRandomArrangement() {
        let fleet: [(number: Int, decks: Int)] = [
            (0, 4),
            (1, 3), (2, 3),
            (3, 2), (4, 2), (5, 2),
            (6, 1), (7, 1), (8, 1), (9, 1)
        ]

        var placedShips = [Ship]()
        for _ in 0..<100 { // whole-board attempts
            clearShips() // fresh cells (unknown & available), ships = []
            placedShips = []
            var success = true
            for entry in fleet.shuffled() {
                guard let ship = placeRandomShip(number: entry.number, numberOfDecks: entry.decks, maxTries: 200) else {
                    success = false
                    break
                }
                placedShips.append(ship)
                defineSafeAreaNearShip(ship: ship) // keep a 1-cell gap so ships don't touch
            }
            if success { break }
        }

        makeCellsAvailableAgain()
        placedShips.sort { $0.number < $1.number }
        if self.name == "Player" {
            for ship in placedShips {
                for coordinate in ship.coordinates {
                    self.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus = .showShip
                }
            }
        }
        self.ships = placedShips
        self.shipPositions = Array(repeating: .zero, count: 10)
    }
    
    ///Method marks cells around the ship as unavailable
    func defineSafeAreaNearShip(ship: Ship) {
        let lastIndex = ship.numberOfDecks - 1
        var rowStartOffset = 0
        var rowFinishOffset = 0
        var columnStartOffset = 0
        var columnFinishOffset = 0
        
        if ship.coordinates[0].0 == 1 {
            rowStartOffset = 0 // start from the edge instead of -1
            rowFinishOffset = 1 //finish at the position +1
        } else if ship.coordinates[lastIndex].0 == 10 {
            rowStartOffset = -1
            rowFinishOffset = 0
        } else {
            rowStartOffset = -1
            rowFinishOffset = 1
        }
        if ship.coordinates[0].1 == 1 {
            columnStartOffset = 0 // start from the edge instead of -1
            columnFinishOffset = 1 //finish at the position +1
        } else if ship.coordinates[lastIndex].1 == 10 {
            columnStartOffset = -1
            columnFinishOffset = 0
        } else {
            columnStartOffset = -1
            columnFinishOffset = 1
        }
        for row in ship.coordinates[0].0 + rowStartOffset...ship.coordinates[ship.numberOfDecks-1].0 + rowFinishOffset {
            for column in ship.coordinates[0].1 + columnStartOffset...ship.coordinates[ship.numberOfDecks-1].1 + columnFinishOffset {
                self.cells[row - 1][column - 1].isAvailable = false
            }
        }
    }
    
    ///Method makes all the cells around ships available again
    func makeCellsAvailableAgain() { // only for player cells
        for x in 0 ..< 10 {
            for y in 0 ..< 10 {
                self.cells[x][y].isAvailable = true
            }
        }
    }
    
    ///Tries up to `maxTries` random positions for a ship. RETURNS: a valid Ship, or nil if none was found.
    private func placeRandomShip(number: Int, numberOfDecks: Int, maxTries: Int) -> Ship? {
        for _ in 0..<maxTries {
            let orientation: Ship.Orientation = Bool.random() ? .horizontal : .vertical
            var coordinates: [(Int, Int)] = []
            if orientation == .horizontal {
                let row = Int.random(in: 0...9)
                let column = Int.random(in: 0...10 - numberOfDecks)
                for i in column + 1...column + numberOfDecks {
                    coordinates.append((row + 1, i))
                }
            } else {
                let row = Int.random(in: 0...10 - numberOfDecks)
                let column = Int.random(in: 0...9)
                for i in row + 1...row + numberOfDecks {
                    coordinates.append((i, column + 1))
                }
            }
            if cellIsAvailableForPlacingShip(coordinates: coordinates) {
                return Ship(number: number, orientation: orientation, numberOfDecks: numberOfDecks, coordinates: coordinates)
            }
        }
        return nil
    }
    
    ///Method checks if all the cells are available for placing ship. ACCEPTS: Array of cells. RETURNS: true or false
    func cellIsAvailableForPlacingShip(coordinates: [(Int, Int)]) -> Bool {
        for coordinate in coordinates {
            let row = coordinate.0 - 1
            let column = coordinate.1 - 1
            
            if !self.cells.indices.contains(row) || !self.cells[row].indices.contains(column) {
                return false
            }
            
            guard self.cells[row][column].isAvailable else {
                return false
            }
        }
        return true
    }
    
    ///Method defines a center points of the ships and writes them to array.
    func defineShipPositionsAsCGPoint(leftTopPointOfGameField: CGPoint, cellSize: CGFloat) {
        self.shipPositions = []
        for ship in self.ships {
            if let lastCoordinate = ship.coordinates.last {
                var correctionX: CGFloat = .zero
                var correctionY: CGFloat = .zero
                if ship.orientation == .vertical {
                    correctionX = -cellSize / 2
                    correctionY = -(CGFloat(ship.numberOfDecks) * cellSize) / 2
                } else if ship.orientation == .horizontal {
                    correctionX = -(CGFloat(ship.numberOfDecks) * cellSize) / 2
                    correctionY = -cellSize / 2
                }
                let x = CGFloat(lastCoordinate.1) * cellSize + leftTopPointOfGameField.x + correctionX
                let y = CGFloat(lastCoordinate.0) * cellSize + leftTopPointOfGameField.y + correctionY
                self.shipPositions.append(CGPoint(x: x, y: y))
            }
        }
    }
    
    ///Method clears all the ships from the field
    func clearShips() {
        self.cells = []
        self.ships = []
        for row in 1...10 {
            var arrayOfrows = [Cell]()
            for column in 1...10 {
                arrayOfrows.append(Cell(column: column, row: row))
            }
            self.cells.append(arrayOfrows)
        }
    }
    
    init(name: String) {
        self.name = name
        var boolArray = [Bool]()
        for row in 1...10 {
            var arrayOfRows = [Cell]()
            for column in 1...10 {
                arrayOfRows.append(Cell(column: column, row: row))
                boolArray.append(false)
            }
            self.cells.append(arrayOfRows)
            self.fireStrokeArray.append(boolArray)
        }
    }
}
