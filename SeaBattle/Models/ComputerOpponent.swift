//
//  ComputerOpponent.swift
//  SeaBattle
//
//  Phase 0: the computer player, behind the `Opponent` protocol. It owns ONLY
//  the targeting decision — which cell to fire at — while the board mutation
//  lives in `GameEngine`. This is the seam where the Expert AI (Phase 4:
//  probability-density heat map + Monte-Carlo constraint sampling) will slot
//  in, replacing the placeholder logic in `meetConditionsToDefineCellForFire`.
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
        // Expert uses the probability-density heat map; other levels use the
        // simple random hunt + priority-cell finishing.
        if appState.difficultyLevel == .expert, let shot = expertShot() {
            return shot
        }
        let (row, column) = findAvailableCellsForFire()
        return Coordinate(row: row, column: column)
    }

    /// Priority-target state lives in `appState.potentialCellsForFinishingDamagedShip`
    /// and is maintained by `GameEngine` as shots land, so nothing to do here yet.
    func reportOutcome(_ outcome: ShotOutcome, at coordinate: Coordinate) async {}

    // MARK: - Expert targeting (probability-density heat map)

    /// The AI's knowledge of a cell, using only publicly-available information
    /// (never the hidden ship positions).
    private enum CellKnowledge {
        case unknown  // not yet fired at; a ship could be here
        case hit      // hit, part of a ship that isn't fully sunk yet
        case blocked  // a miss, a sunk-ship cell, or a known-empty safe-area cell
    }

    /// Picks the cell most likely to contain a ship, by counting, for every
    /// remaining ship, all legal placements that pass through each cell. Cells
    /// covered by placements that also explain an existing hit are weighted far
    /// higher, which naturally finishes a damaged ship. This is the same idea as
    /// a human "where can the biggest remaining ship still fit?". Returns nil if
    /// it can't decide, so the caller falls back to the simple hunt.
    private func expertShot() -> Coordinate? {
        var knowledge = [[CellKnowledge]](repeating: [CellKnowledge](repeating: .unknown, count: 10), count: 10)
        var hasHits = false
        for r in 0..<10 {
            for c in 0..<10 {
                let cell = targetBoard.cells[r][c]
                switch cell.cellStatus {
                case .showShipOnFire:
                    knowledge[r][c] = .hit
                    hasHits = true
                case .destroyed, .missed:
                    knowledge[r][c] = .blocked
                default:
                    // .unknown / .showShip / .showShipHalo — shootable unless the
                    // cell was marked unavailable (safe area around a sunk ship).
                    knowledge[r][c] = cell.isAvailable ? .unknown : .blocked
                }
            }
        }

        let remainingSizes = remainingShipSizes()
        guard !remainingSizes.isEmpty else { return nil }

        var heat = [[Int]](repeating: [Int](repeating: 0, count: 10), count: 10)
        let hitWeight = 50

        // Hunt mode (no open hits): concentrate on where the LARGEST remaining
        // ship can still fit — the fastest way to corner big ships, and exactly
        // the human expert strategy. Finishing mode considers every size so it
        // can complete whatever was hit.
        let sizesToConsider: [Int] = hasHits ? Array(Set(remainingSizes)) : [remainingSizes.max()!]

        for size in sizesToConsider {
            let multiplicity = hasHits ? remainingSizes.filter { $0 == size }.count : 1
            for isHorizontal in [true, false] {
                let maxRow = isHorizontal ? 10 : 10 - size
                let maxCol = isHorizontal ? 10 - size : 10
                for r in 0..<maxRow {
                    for c in 0..<maxCol {
                        let cells: [(Int, Int)] = (0..<size).map { i in
                            isHorizontal ? (r, c + i) : (r + i, c)
                        }
                        guard isPlacementLegal(cells, knowledge: knowledge) else { continue }
                        let coversHit = cells.contains { knowledge[$0.0][$0.1] == .hit }
                        // When a ship is already damaged, only placements that
                        // could finish it are worth considering.
                        if hasHits && !coversHit { continue }
                        let weight = (coversHit ? hitWeight : 1) * multiplicity
                        for (cr, cc) in cells where knowledge[cr][cc] == .unknown {
                            heat[cr][cc] += weight
                        }
                    }
                }
            }
        }

        var best: (row: Int, column: Int)?
        var bestScore = 0
        for r in 0..<10 {
            for c in 0..<10 where knowledge[r][c] == .unknown && heat[r][c] > bestScore {
                bestScore = heat[r][c]
                best = (r, c)
            }
        }
        guard let target = best else { return nil }
        return Coordinate(row: target.row + 1, column: target.column + 1)
    }

    /// A placement is legal if all its cells are `.unknown` or `.hit`, and none
    /// of its cells is orthogonally or diagonally adjacent to a sunk-ship cell
    /// (ships never touch).
    private func isPlacementLegal(_ cells: [(Int, Int)], knowledge: [[CellKnowledge]]) -> Bool {
        for (r, c) in cells {
            if knowledge[r][c] == .blocked { return false }
            for dr in -1...1 {
                for dc in -1...1 where dr != 0 || dc != 0 {
                    let nr = r + dr, nc = c + dc
                    if nr >= 0, nr < 10, nc >= 0, nc < 10,
                       targetBoard.cells[nr][nc].cellStatus == .destroyed {
                        return false
                    }
                }
            }
        }
        return true
    }

    /// The sizes of ships not yet sunk, inferred from the sunk (destroyed) cell
    /// clusters — public information, not the hidden fleet layout.
    private func remainingShipSizes() -> [Int] {
        var fleet = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]
        var visited = [[Bool]](repeating: [Bool](repeating: false, count: 10), count: 10)
        for r in 0..<10 {
            for c in 0..<10 where targetBoard.cells[r][c].cellStatus == .destroyed && !visited[r][c] {
                var size = 0
                var stack = [(r, c)]
                visited[r][c] = true
                while let (cr, cc) = stack.popLast() {
                    size += 1
                    for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                        let nr = cr + dr, nc = cc + dc
                        if nr >= 0, nr < 10, nc >= 0, nc < 10, !visited[nr][nc],
                           targetBoard.cells[nr][nc].cellStatus == .destroyed {
                            visited[nr][nc] = true
                            stack.append((nr, nc))
                        }
                    }
                }
                if let index = fleet.firstIndex(of: size) { fleet.remove(at: index) }
            }
        }
        return fleet
    }

    // MARK: - Simple targeting (easy / medium / hard)

    /// Chooses one cell from the array of possible cells. RETURNS: coordinates (row, column).
    private func findAvailableCellsForFire() -> (Int, Int) {
        var coordinates: (Int, Int) = (0, 0)
        repeat {
            // If some ship was damaged, we need to find its undamaged cells first.
            // Only consider priority cells that are in bounds and still available; a
            // priority list made up entirely of unavailable cells used to spin forever.
            let availablePriorityCells = (appState.potentialCellsForFinishingDamagedShip ?? []).filter { candidate in
                (1...10).contains(candidate.0) && (1...10).contains(candidate.1)
                    && targetBoard.cells[candidate.0 - 1][candidate.1 - 1].isAvailable
            }
            if let priorityCell = availablePriorityCells.randomElement() {
                coordinates = priorityCell
            } else {
                coordinates = (Int.random(in: 1...10), Int.random(in: 1...10))
            }
        } while !meetConditionsToDefineCellForFire(coordinates: coordinates)
        return coordinates
    }

    /// Checks additional conditions for a cell in terms of difficulty level.
    /// RETURNS: true or false.
    private func meetConditionsToDefineCellForFire(coordinates: (Int, Int)) -> Bool {
        let row = coordinates.0
        let column = coordinates.1
        switch appState.difficultyLevel {
        case .easy:
            return targetBoard.cells[row - 1][column - 1].isAvailable ? true : false
        case .medium:
            return targetBoard.cells[row - 1][column - 1].isAvailable ? true : false
            // more logic
        case .hard:
            return targetBoard.cells[row - 1][column - 1].isAvailable ? true : false
            // more complex logic here to come
            // define minimum decks of remaining ships
            // define cells nearby to fit the smallest enemy ship
            // logic to define the most relevant cell to fire (cross?)
        case .expert:
            // Phase 4: probability-density heat map + Monte-Carlo constraint
            // sampling + full "ships don't touch" reasoning. Falls back to the
            // hard-level behaviour until the Expert AI lands.
            return targetBoard.cells[row - 1][column - 1].isAvailable ? true : false
        }
    }
}
