//
//  ComputerOpponent.swift
//  SeaBattle
//
//  The computer player, behind the `Opponent` protocol. It owns ONLY the
//  targeting decision — which cell to fire at — while board mutation lives in
//  the rules core.
//
//  Since R0.4 it reads `Board.opponentView()`, which hides unharmed ship cells,
//  so the AI physically cannot consult the layout it is meant to be hunting
//  for. Candidate cells come from `Board.shootableCells(...)`; the old version
//  drew random coordinates in a `repeat … while` until one happened to be free,
//  which took an unbounded number of tries once the board filled up (audit
//  finding B16).
//
//  The difficulty ladder itself is still flat — medium and hard behave alike
//  (finding A6). R0.6 gives each level its own behaviour; this file only moves
//  the existing behaviour onto the core, unchanged.
//

import Foundation

@MainActor
final class ComputerOpponent: Opponent {

    let displayName = "Computer"

    /// The board the computer is firing at (the human player's field).
    private let targetBoard: PlayerData
    /// The computer's own fleet.
    private let ownFleet: PlayerData
    private let appState: AppState

    init(appState: AppState, ownFleet: PlayerData, targetBoard: PlayerData) {
        self.appState = appState
        self.ownFleet = ownFleet
        self.targetBoard = targetBoard
    }

    func provideFleet() async -> [Ship] {
        ownFleet.shipsRandomArrangement()
        return ownFleet.ships
    }

    func nextShot() async -> Coordinate {
        let board = targetBoard.coreBoard.opponentView()

        // Every level finishes a ship it has already damaged. Ships are
        // straight and never touch, so this is deterministic and needs no
        // probability map — and it guarantees the AI extends an established
        // hit line instead of ever firing sideways.
        if let shot = finishingShot(on: board) { return shot }

        if appState.difficultyLevel == .expert, let shot = expertShot(on: board) {
            return shot
        }
        return huntShot(on: board)
    }

    /// Targeting is recomputed from the board on every shot, so there is no
    /// per-shot state to carry.
    func reportOutcome(_ outcome: ShotOutcome, at coordinate: Coordinate) async {}

    // MARK: - Hunting

    /// A cell picked at random from those still worth firing at.
    ///
    /// On `.easy` the ring around a sunk ship stays in play, so the computer
    /// wastes shots there the way a careless human would. Every other level
    /// rules it out — ships never touch, so no ship can be there. That is
    /// exactly the distinction the old `defineSafeAreaNearShip` call made, now
    /// derived from the board instead of cached as a per-cell flag.
    private func huntShot(on board: Board) -> Coordinate {
        let excludeRings = appState.difficultyLevel != .easy
        if let pick = board.shootableCells(excludingRingsAroundSunk: excludeRings).randomElement() {
            return pick
        }
        // Excluding the rings can in principle rule out everything that is
        // left; fall back to the unrestricted list before giving up.
        return board.shootableCells().randomElement() ?? Coordinate(row: 1, column: 1)
    }

    /// Finishes a ship that has been hit but not sunk. With two or more
    /// collinear hits the orientation is known, so only the cells extending
    /// that line are candidates; a single isolated hit probes its four
    /// orthogonal neighbours. RETURNS nil when there is nothing to finish.
    private func finishingShot(on board: Board) -> Coordinate? {
        let hits = Board.allCoordinates.filter { board[$0] == .hit }
        guard !hits.isEmpty else { return nil }

        func isHit(_ coordinate: Coordinate) -> Bool {
            coordinate.isOnBoard && board[coordinate] == .hit
        }
        func shootable(_ coordinate: Coordinate) -> Bool {
            coordinate.isOnBoard && board[coordinate].isUnshot
        }

        // Extend an established line to either end.
        var lineCandidates = Set<Coordinate>()
        for hit in hits {
            if isHit(Coordinate(row: hit.row, column: hit.column - 1))
                || isHit(Coordinate(row: hit.row, column: hit.column + 1)) {
                lineCandidates.formUnion(
                    ends(from: hit, rowStep: 0, columnStep: 1, isHit: isHit, shootable: shootable))
            }
            if isHit(Coordinate(row: hit.row - 1, column: hit.column))
                || isHit(Coordinate(row: hit.row + 1, column: hit.column)) {
                lineCandidates.formUnion(
                    ends(from: hit, rowStep: 1, columnStep: 0, isHit: isHit, shootable: shootable))
            }
        }
        if let pick = lineCandidates.randomElement() { return pick }

        // No line yet — probe around the lone hit.
        return hits.flatMap(\.orthogonalNeighbours).filter(shootable).randomElement()
    }

    /// Walks off both ends of the run of hits through `origin` along one axis
    /// and returns whichever ends can still be fired at.
    private func ends(from origin: Coordinate,
                      rowStep: Int,
                      columnStep: Int,
                      isHit: (Coordinate) -> Bool,
                      shootable: (Coordinate) -> Bool) -> [Coordinate] {
        var result: [Coordinate] = []
        for direction in [-1, 1] {
            var candidate = Coordinate(row: origin.row + rowStep * direction,
                                       column: origin.column + columnStep * direction)
            while isHit(candidate) {
                candidate = Coordinate(row: candidate.row + rowStep * direction,
                                       column: candidate.column + columnStep * direction)
            }
            if shootable(candidate) { result.append(candidate) }
        }
        return result
    }

    // MARK: - Expert targeting (probability-density heat map)

    /// Picks the cell most likely to hold a ship by counting, for the largest
    /// ship still afloat, every legal placement passing through each cell —
    /// the same reasoning as a human asking "where can the big one still fit?".
    /// RETURNS nil if it cannot decide, so the caller falls back to hunting.
    ///
    /// Only reached when nothing is damaged: `finishingShot` handles that case
    /// first, and deterministically.
    private func expertShot(on board: Board) -> Coordinate? {
        guard let longest = board.remainingShipLengths().max() else { return nil }

        // Cells ruled out for good: already shot at, or in the ring of a sunk
        // ship, where the rules forbid another ship.
        let open = Set(board.shootableCells(excludingRingsAroundSunk: true))
        guard !open.isEmpty else { return nil }

        var heat: [Coordinate: Int] = [:]
        for orientation in Orientation.allCases {
            let maxRow = orientation == .vertical ? Board.size - longest + 1 : Board.size
            let maxColumn = orientation == .horizontal ? Board.size - longest + 1 : Board.size
            guard maxRow >= 1, maxColumn >= 1 else { continue }
            for row in 1...maxRow {
                for column in 1...maxColumn {
                    let candidate = ShipPlacement(length: longest,
                                                  origin: Coordinate(row: row, column: column),
                                                  orientation: orientation)
                    guard candidate.cells.allSatisfy({ open.contains($0) }) else { continue }
                    for cell in candidate.cells { heat[cell, default: 0] += 1 }
                }
            }
            // A one-deck ship is the same either way round; counting it twice
            // would only double every tally.
            if longest == 1 { break }
        }
        guard let peak = heat.values.max() else { return nil }

        // Break ties towards the cell that rules out the most: a central cell
        // deactivates more of its surroundings when it sinks, which keeps the
        // all-single-deck endgame away from the edges.
        return heat
            .filter { $0.value == peak }
            .max { openNeighbours($0.key, open) < openNeighbours($1.key, open) }?
            .key
    }

    /// How many still-shootable cells surround `coordinate`.
    private func openNeighbours(_ coordinate: Coordinate, _ open: Set<Coordinate>) -> Int {
        coordinate.neighbours.count { open.contains($0) }
    }
}
