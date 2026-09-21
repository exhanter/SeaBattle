//
//  ShipPlacement.swift
//  SeaBattle
//
//  R0.3, pure rules core. A ship is described by where it starts, how long it
//  is and which way it lies — the occupied cells are DERIVED, never stored.
//  The old `Ship` stored `coordinates: [(Int, Int)]` alongside `orientation`
//  and `numberOfDecks`, which could disagree with each other, needed a
//  hand-written `Codable` (tuples aren't codable) and blocked `Equatable`
//  (audit finding B3).
//

import Foundation

/// One ship at one position on the board.
struct ShipPlacement: Codable, Sendable, Hashable, Identifiable {

    let id: UUID
    /// Number of decks: 4, 3, 2 or 1 in the standard fleet.
    let length: Int
    /// The topmost cell for a vertical ship, the leftmost for a horizontal one.
    var origin: Coordinate
    var orientation: Orientation

    init(id: UUID = UUID(), length: Int, origin: Coordinate, orientation: Orientation) {
        self.id = id
        self.length = length
        self.origin = origin
        self.orientation = orientation
    }

    /// The cells the ship occupies, from `origin` outwards.
    var cells: [Coordinate] {
        (0..<length).map { step in
            switch orientation {
            case .horizontal: return Coordinate(row: origin.row, column: origin.column + step)
            case .vertical:   return Coordinate(row: origin.row + step, column: origin.column)
            }
        }
    }

    /// Whether every cell of the ship is inside the field.
    var isOnBoard: Bool { cells.allSatisfy(\.isOnBoard) }

    /// The ship's own cells plus the one-cell ring around them. Two ships may
    /// not touch, so two ships are compatible exactly when one ship's cells do
    /// not intersect the other's footprint.
    var footprint: Set<Coordinate> {
        var result = Set<Coordinate>()
        for cell in cells {
            result.insert(cell)
            result.formUnion(cell.neighbours)
        }
        return result
    }

    /// The ring around the ship: the footprint minus the ship itself. This is
    /// what the beginner "reveal empty cells around a sunk ship" option fills
    /// in, and what the AI may exclude once a ship is sunk.
    var ring: [Coordinate] {
        let own = Set(cells)
        return footprint.subtracting(own).sorted { lhs, rhs in
            (lhs.row, lhs.column) < (rhs.row, rhs.column)
        }
    }

    func contains(_ coordinate: Coordinate) -> Bool {
        switch orientation {
        case .horizontal:
            return coordinate.row == origin.row
                && (origin.column..<(origin.column + length)).contains(coordinate.column)
        case .vertical:
            return coordinate.column == origin.column
                && (origin.row..<(origin.row + length)).contains(coordinate.row)
        }
    }

    /// Turns the ship 90°, keeping the cell nearest the middle of the ship in
    /// place so it rotates around itself rather than swinging off `origin`.
    /// The result can be off the board or illegal — the caller validates.
    func rotated() -> ShipPlacement {
        let pivotOffset = (length - 1) / 2
        let pivot: Coordinate
        switch orientation {
        case .horizontal: pivot = Coordinate(row: origin.row, column: origin.column + pivotOffset)
        case .vertical:   pivot = Coordinate(row: origin.row + pivotOffset, column: origin.column)
        }
        let newOrigin: Coordinate
        switch orientation {
        case .horizontal: newOrigin = Coordinate(row: pivot.row - pivotOffset, column: pivot.column)
        case .vertical:   newOrigin = Coordinate(row: pivot.row, column: pivot.column - pivotOffset)
        }
        return ShipPlacement(id: id, length: length, origin: newOrigin, orientation: orientation.toggled)
    }

    /// The same ship moved so that it starts at `newOrigin`.
    func moved(to newOrigin: Coordinate) -> ShipPlacement {
        ShipPlacement(id: id, length: length, origin: newOrigin, orientation: orientation)
    }
}

// MARK: - Fleet

/// The standard fleet and the rules for arranging it.
enum FleetLayout {

    /// One 4-deck, two 3-deck, three 2-deck, four 1-deck ships.
    static let deckCounts = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]
    static var shipCount: Int { deckCounts.count }
    /// 20 cells are occupied by ships on a full board.
    static var occupiedCellCount: Int { deckCounts.reduce(0, +) }

    /// The ships that overlap another ship, touch one, or hang off the board.
    /// An empty result means the layout is legal. The redesign paints exactly
    /// these ships in the pink "denied" ramp while arranging (spec 4.3).
    static func conflicts(in ships: [ShipPlacement]) -> Set<UUID> {
        var conflicting = Set<UUID>()
        for ship in ships where !ship.isOnBoard {
            conflicting.insert(ship.id)
        }
        for (index, ship) in ships.enumerated() {
            let own = Set(ship.cells)
            for other in ships[(index + 1)...] {
                // Ships may not share a cell, and may not sit in each other's
                // ring — checking one footprint against the other's cells is
                // enough, because the ring relation is symmetric.
                if !own.isDisjoint(with: other.footprint) {
                    conflicting.insert(ship.id)
                    conflicting.insert(other.id)
                }
            }
        }
        return conflicting
    }

    static func isValid(_ ships: [ShipPlacement]) -> Bool {
        ships.count == shipCount
            && ships.map(\.length).sorted(by: >) == deckCounts.sorted(by: >)
            && conflicts(in: ships).isEmpty
    }

    /// A fresh random arrangement of the full fleet.
    ///
    /// Ships are placed in a RANDOM order, not largest-first, and the whole
    /// board restarts if one of them cannot be fitted. A fixed largest-first
    /// order makes the leftover free cells cluster at the edges, so single-deck
    /// ships end up on the perimeter and become predictable; shuffling the
    /// order spreads them out. The result is returned longest-first so the UI
    /// can address ships in a stable order.
    static func random<G: RandomNumberGenerator>(using generator: inout G) -> [ShipPlacement] {
        for _ in 0..<200 {
            var placed: [ShipPlacement] = []
            var blocked = Set<Coordinate>()
            var failed = false

            for length in deckCounts.shuffled(using: &generator) {
                guard let ship = placeOne(length: length, blocked: blocked, using: &generator) else {
                    failed = true
                    break
                }
                placed.append(ship)
                blocked.formUnion(ship.footprint)
            }
            if !failed { return placed.sorted { $0.length > $1.length } }
        }
        // Unreachable in practice — a 10 x 10 board fits this fleet easily, and
        // 200 whole-board attempts have never all failed. Falling back to the
        // canonical corner layout is still better than returning nothing.
        return canonicalLayout()
    }

    static func random() -> [ShipPlacement] {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    private static func placeOne<G: RandomNumberGenerator>(
        length: Int,
        blocked: Set<Coordinate>,
        using generator: inout G
    ) -> ShipPlacement? {
        // Enumerate every legal position once and pick uniformly, instead of
        // throwing darts until one sticks: the board gets crowded towards the
        // end of a layout and rejection sampling wastes an unbounded number of
        // tries there (the same problem as audit finding B16).
        var candidates: [ShipPlacement] = []
        for orientation in Orientation.allCases {
            let maxRow = orientation == .vertical ? Board.size - length + 1 : Board.size
            let maxColumn = orientation == .horizontal ? Board.size - length + 1 : Board.size
            guard maxRow >= 1, maxColumn >= 1 else { continue }
            for row in 1...maxRow {
                for column in 1...maxColumn {
                    let ship = ShipPlacement(length: length,
                                             origin: Coordinate(row: row, column: column),
                                             orientation: orientation)
                    if ship.cells.allSatisfy({ !blocked.contains($0) }) {
                        candidates.append(ship)
                    }
                }
            }
            // A single-deck ship is the same in both orientations; enumerating
            // it twice would double its candidate list for no reason.
            if length == 1 { break }
        }
        return candidates.randomElement(using: &generator)
    }

    /// A fixed legal layout: every ship on an odd row with at least one clear
    /// column between neighbours. Used as the fallback above and as a fixture
    /// in tests, where a known board beats a random one.
    static func canonicalLayout() -> [ShipPlacement] {
        let positions: [(length: Int, row: Int, column: Int)] = [
            (4, 1, 1), (3, 1, 6),
            (3, 3, 1), (2, 3, 5), (2, 3, 8),
            (2, 5, 1), (1, 5, 4), (1, 5, 6), (1, 5, 8), (1, 5, 10)
        ]
        return positions.map {
            ShipPlacement(length: $0.length,
                          origin: Coordinate(row: $0.row, column: $0.column),
                          orientation: .horizontal)
        }
    }
}
