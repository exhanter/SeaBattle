//
//  Side.swift
//  SeaBattle
//
//  R0.3, part of the pure rules core (`Models/Core`). Nothing in this folder
//  knows about SwiftUI, AppState, sound or persistence: it is plain value types
//  and pure functions, so it can be reasoned about and tested on its own.
//
//  `Side` replaces the `name == "Player"` / `name == "Enemy"` string comparisons
//  that used to decide behavior across the engine (audit finding A2). A side is
//  a ROLE, not a name: in hot-seat and network play both sides are humans with
//  their own display names, and the redesign paints the role — warm for you,
//  cool for the opponent — identically in every mode.
//

import Foundation

/// Which of the two boards in a match is meant.
enum Side: String, Codable, Sendable, CaseIterable {
    /// The board belonging to the person holding the device right now.
    case you
    /// The board belonging to whoever they are playing against.
    case foe

    var opposite: Side {
        switch self {
        case .you: return .foe
        case .foe: return .you
        }
    }
}

/// How a ship lies on the board.
enum Orientation: String, Codable, Sendable, CaseIterable {
    case horizontal
    case vertical

    var toggled: Orientation {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}

// MARK: - Coordinate helpers

extension Coordinate {
    /// Whether this coordinate falls inside the 10 x 10 field. Coordinates are
    /// 1-based, so both row and column must be in 1...10.
    var isOnBoard: Bool {
        (1...Board.size).contains(row) && (1...Board.size).contains(column)
    }

    /// The up to eight surrounding cells that are still on the board. Ships may
    /// not touch, not even diagonally, so this is the ring that has to stay
    /// clear around every ship.
    var neighbours: [Coordinate] {
        var result: [Coordinate] = []
        result.reserveCapacity(8)
        for deltaRow in -1...1 {
            for deltaColumn in -1...1 where deltaRow != 0 || deltaColumn != 0 {
                let candidate = Coordinate(row: row + deltaRow, column: column + deltaColumn)
                if candidate.isOnBoard { result.append(candidate) }
            }
        }
        return result
    }

    /// The four orthogonally adjacent cells that are still on the board.
    var orthogonalNeighbours: [Coordinate] {
        [Coordinate(row: row - 1, column: column),
         Coordinate(row: row + 1, column: column),
         Coordinate(row: row, column: column - 1),
         Coordinate(row: row, column: column + 1)]
            .filter(\.isOnBoard)
    }
}
