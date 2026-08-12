//
//  Coordinate.swift
//  SeaBattle
//
//  Phase 0: Codable coordinate type that replaces the (Int, Int) tuples used
//  across the game logic. A serializable coordinate is the prerequisite for
//  saving games (Phase 1), hot-seat and network play (Phases 5/5a).
//

import Foundation

/// A 1-based board coordinate. `row` and `column` both range 1...10 for the
/// standard field, matching the existing tuple convention where `.0` was the
/// row and `.1` was the column.
struct Coordinate: Codable, Hashable, Sendable {
    let row: Int
    let column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// Bridges from the legacy `(Int, Int)` tuple representation.
    init(_ tuple: (Int, Int)) {
        self.row = tuple.0
        self.column = tuple.1
    }

    /// Bridges back to the legacy `(Int, Int)` tuple representation still used
    /// by the game logic until the engine is fully migrated.
    var tuple: (Int, Int) { (row, column) }
}
