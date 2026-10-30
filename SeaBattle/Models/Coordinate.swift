//
//  Coordinate.swift
//  SeaBattle
//
//  Phase 0: Codable coordinate type that replaced the (Int, Int) tuples of the
//  original game logic (the last of them went with `PlayerData`, 30.10). A serializable coordinate is the prerequisite for
//  saving games (Phase 1), hot-seat and network play (Phases 5/5a).
//

import Foundation

/// A 1-based board coordinate. `row` and `column` both range 1...10 for the
/// standard field.
struct Coordinate: Codable, Hashable, Sendable {
    let row: Int
    let column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}
