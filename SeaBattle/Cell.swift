//
//  Cell.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 12/07/2024.
//

import Foundation

struct Cell {
    enum CurrentStatus {
        case unknown
        case missed
        case onFire
        case destroyed
        case showShip
        case showShipOnFire
        case showShipHalo
    }
    let column: Int
    let row: Int
    var isAvailable = true
    var cellStatus = CurrentStatus.unknown
    init(column: Int, row: Int, isAvailable: Bool = true, cellStatus: Cell.CurrentStatus = CurrentStatus.unknown) {
        self.column = column
        self.row = row
        self.isAvailable = isAvailable
        self.cellStatus = cellStatus
    }
}


