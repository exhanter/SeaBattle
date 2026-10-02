//
//  Data.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import Foundation
import Observation

@Observable
class PlayerData {

    /// Which role this board plays. Replaces the `name == "Player"` string
    /// comparisons that used to decide behaviour across the engine (audit A2).
    let side: Side

    /// Legacy identifier still written into `GameSnapshot`. Derived from `side`
    /// so the two can never disagree.
    var name: String { side == .you ? "Player" : "Enemy" }

    var cells = [[Cell]]()
    var ships = [Ship]()
    var showFinishGameAlert = false
    var shipsDestroyed: [Ship] {
        return ships.filter{ $0.isDestroyed }
    }
    var numberShipsDestroyed: Int {
        return shipsDestroyed.count
    }

    var fireStrokeArray = [[Bool]]()
    
    /// A fresh random fleet. The layout comes from the rules core
    /// (`FleetLayout.random`), so the "ships never touch" rule lives in one
    /// place; only the owner of a board gets to see its hulls (`apply`).
    func shipsRandomArrangement() {
        place(FleetLayout.random())
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
    
    convenience init(name: String) {
        self.init(side: name == "Player" ? .you : .foe)
    }

    init(side: Side) {
        self.side = side
        // One row of 10 per board row. The old code reused a single growing
        // `boolArray`, so row N ended up with (N + 1) * 10 entries.
        for row in 1...10 {
            var arrayOfRows = [Cell]()
            for column in 1...10 {
                arrayOfRows.append(Cell(column: column, row: row))
            }
            self.cells.append(arrayOfRows)
            self.fireStrokeArray.append([Bool](repeating: false, count: 10))
        }
    }
}
