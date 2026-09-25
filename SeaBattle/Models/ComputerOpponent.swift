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
//  R0.6 gave the four levels four different behaviours — before it, three of
//  them were the same code and only `.easy` differed at all (audit finding A6),
//  so the player was choosing between "easy" and "one of three identical
//  hards". Each level adds exactly one idea to the one below it:
//
//    easy    fires at random, and never learns anything.
//    medium  finishes a ship it has damaged, and stops wasting shots in the
//            ring around a sunk one.
//    hard    hunts on a checkerboard while a ship of 2+ decks is still afloat.
//    expert  hunts by probability density (a heat map) instead.
//
//  The whole decision is a pure function of the board — there is no per-shot
//  state to keep in sync, and `targetCandidates(on:)` can be asked what a level
//  would consider without firing anything.
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

    /// Arranges a fleet the way `level` does.
    ///
    /// The two top levels hide their ships deliberately; the two lower ones take
    /// a plain random layout. That is the other half of what makes the levels
    /// differ — measured at about twenty shots, against two or three for every
    /// targeting improvement in the ladder put together. See
    /// `DifficultyLevel.fleetExposureTarget` for what "deliberately" means and
    /// why it does not make the computer predictable.
    ///
    /// Synchronous and static on purpose. It used to exist only as the body of
    /// the `async` `provideFleet()` below, **which nothing ever called** — every
    /// screen set the computer's fleet with `shipsRandomArrangement()`, so
    /// hiding never happened in a real match and the two top levels were weaker
    /// than the numbers in `docs/STATUS.md`. The win-rate tests did not catch it
    /// because they arranged the hidden fleet themselves; they now call this.
    static func arrangeFleet(for level: AppState.DifficultyLevel, on board: PlayerData) {
        if let target = level.fleetExposureTarget {
            board.place(FleetLayout.arrangement(givingAwayAtMost: target))
        } else {
            board.shipsRandomArrangement()
        }
    }

    func provideFleet() async -> [Ship] {
        Self.arrangeFleet(for: appState.difficultyLevel, on: ownFleet)
        return ownFleet.ships
    }

    func nextShot() async -> Coordinate {
        let board = targetBoard.coreBoard.opponentView()
        return targetCandidates(on: board).randomElement()
            // Every candidate list can in principle come out empty — the
            // exclusions are allowed to rule out everything that is left — so
            // fall back to "anything unshot" before giving up.
            ?? board.shootableCells().randomElement()
            ?? Coordinate(row: 1, column: 1)
    }

    /// Targeting is recomputed from the board on every shot, so there is no
    /// per-shot state to carry.
    func reportOutcome(_ outcome: ShotOutcome, at coordinate: Coordinate) async {}

    // MARK: - The ladder

    /// Every cell the current level considers equally good to fire at next; the
    /// shot is then drawn from these at random.
    ///
    /// `board` must be an `opponentView()` — a board with the fleet hidden. A
    /// level that got the real board would be cheating, and the tests pass the
    /// masked one for exactly that reason.
    func targetCandidates(on board: Board) -> [Coordinate] {
        switch appState.difficultyLevel {
        case .easy:
            // Finishes a ship it has damaged — otherwise it looks broken rather
            // than easy — but does not use the rule that ships never touch, so
            // it keeps firing into the ring around a sunk one where there
            // cannot be anything. That blind spot alone costs it about thirty
            // shots a match, which is most of what makes this level easy.
            return finishingCandidates(on: board) ?? board.shootableCells()

        case .medium:
            // The same, plus the no-touching rule. Nothing else: everything
            // above this is worth a shot or two at most.
            return finishingCandidates(on: board) ?? openCells(on: board)

        case .hard:
            if let finishing = finishingCandidates(on: board) { return finishing }
            return checkerboardCandidates(on: board)

        case .expert:
            if let finishing = finishingCandidates(on: board) { return finishing }
            if let peak = heatMapPeak(on: board) { return [peak] }
            return openCells(on: board)
        }
    }

    // MARK: - Hunting

    /// Cells still worth firing at, with the ring around every sunk ship ruled
    /// out — ships never touch, so no ship can be there. That is exactly the
    /// distinction the old `defineSafeAreaNearShip` call made, now derived from
    /// the board instead of cached as a per-cell flag.
    private func openCells(on board: Board) -> [Coordinate] {
        board.shootableCells(excludingRingsAroundSunk: true)
    }

    /// Sweeps one colour of a checkerboard. A ship of two or more decks always
    /// covers both colours, so half the board is enough to find every one of
    /// them — and the pattern is what makes this level *look* methodical rather
    /// than lucky, which is most of what a player notices about it.
    ///
    /// The pattern is dropped once only single-deck ships are left: a one-decker
    /// fits on either colour, so sticking to one could never finish the match.
    /// That is the "what is left of the fleet" part, and it reads only
    /// `remainingShipLengths()`, which is derived from the sunk clusters and so
    /// is public knowledge.
    ///
    /// Deliberately no placement counting here — that is `.expert`'s idea, and
    /// R0.6 measured a version of this level that borrowed it: it drew level
    /// with expert, which is finding A6 again with better code. A ladder needs
    /// a rung between "follows up its hits" and "plays as well as the board
    /// allows", and structure without arithmetic is exactly that rung.
    ///
    /// The colour is fixed rather than chosen per shot on purpose: picking the
    /// emptier colour each time would alternate between the two and cover the
    /// whole board evenly, which is the very thing the pattern avoids.
    private func checkerboardCandidates(on board: Board) -> [Coordinate] {
        let open = openCells(on: board)
        guard board.remainingShipLengths().contains(where: { $0 >= 2 }) else {
            return open
        }
        let onPattern = open.filter { ($0.row + $0.column).isMultiple(of: 2) }
        // The colour can run out while the other still holds ships.
        return onPattern.isEmpty ? open : onPattern
    }

    /// Finishes a ship that has been hit but not sunk. With two or more
    /// collinear hits the orientation is known, so only the cells extending
    /// that line are candidates; a single isolated hit probes its four
    /// orthogonal neighbours. RETURNS nil when there is nothing to finish.
    private func finishingCandidates(on board: Board) -> [Coordinate]? {
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
        if !lineCandidates.isEmpty { return Array(lineCandidates) }

        // No line yet — probe around the lone hit.
        let probes = hits.flatMap(\.orthogonalNeighbours).filter(shootable)
        // Damage with nowhere left to extend: the hits are boxed in by earlier
        // shots, so there is nothing to finish after all.
        return probes.isEmpty ? nil : Array(Set(probes))
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

    /// Picks the cell most likely to hold a ship by counting, for every ship
    /// still afloat, all the ways it could still be lying across that cell —
    /// the same reasoning as a human asking "where can what is left still fit?".
    /// RETURNS nil if it cannot decide, so the caller falls back to hunting.
    ///
    /// Only reached when nothing is damaged: `finishingCandidates` handles that
    /// case first, and deterministically.
    ///
    /// Every remaining ship is counted, not just the longest one. R0.6 measured
    /// the longest-ship-only version this replaced and it needed the same
    /// number of shots as `.medium` — a heat map drawn from one four-decker
    /// says little once that ship is sunk, which is most of the match.
    private func heatMapPeak(on board: Board) -> Coordinate? {
        let heat = placementCounts(on: board, lengths: board.remainingShipLengths())
        guard let peak = heat.values.max() else { return nil }
        let open = Set(openCells(on: board))

        // Break ties towards the cell that rules out the most: a central cell
        // deactivates more of its surroundings when it sinks, which keeps the
        // all-single-deck endgame away from the edges.
        return heat
            .filter { $0.value == peak }
            .max { openNeighbours($0.key, open) < openNeighbours($1.key, open) }?
            .key
    }

    /// For every cell still worth firing at, how many ways a ship of one of the
    /// given lengths could be lying across it. A cell no such ship can cover
    /// does not appear at all.
    ///
    /// Shared by `.hard` and `.expert` — the levels differ in what they pass
    /// in and what they do with the answer. Derived only from public knowledge:
    /// the lengths come from `remainingShipLengths()`, which reads the sunk
    /// clusters, and the open cells from what has been fired at.
    private func placementCounts(on board: Board, lengths: [Int]) -> [Coordinate: Int] {
        let open = Set(openCells(on: board))
        guard !lengths.isEmpty, !open.isEmpty else { return [:] }

        var heat: [Coordinate: Int] = [:]
        for length in lengths {
            for orientation in Orientation.allCases {
                let maxRow = orientation == .vertical ? Board.size - length + 1 : Board.size
                let maxColumn = orientation == .horizontal ? Board.size - length + 1 : Board.size
                guard maxRow >= 1, maxColumn >= 1 else { continue }
                for row in 1...maxRow {
                    for column in 1...maxColumn {
                        let candidate = ShipPlacement(length: length,
                                                      origin: Coordinate(row: row, column: column),
                                                      orientation: orientation)
                        guard candidate.cells.allSatisfy({ open.contains($0) }) else { continue }
                        for cell in candidate.cells { heat[cell, default: 0] += 1 }
                    }
                }
                // A one-deck ship is the same either way round; counting it
                // twice would only double every tally.
                if length == 1 { break }
            }
        }
        return heat
    }

    /// How many still-shootable cells surround `coordinate`.
    private func openNeighbours(_ coordinate: Coordinate, _ open: Set<Coordinate>) -> Int {
        coordinate.neighbours.count { open.contains($0) }
    }
}
