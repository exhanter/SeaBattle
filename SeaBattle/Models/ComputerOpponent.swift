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
        let (row, column) = findAvailableCellsForFire()
        return Coordinate(row: row, column: column)
    }

    /// Priority-target state lives in `appState.potentialCellsForFinishingDamagedShip`
    /// and is maintained by `GameEngine` as shots land, so nothing to do here yet.
    func reportOutcome(_ outcome: ShotOutcome, at coordinate: Coordinate) async {}

    // MARK: - Targeting

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
