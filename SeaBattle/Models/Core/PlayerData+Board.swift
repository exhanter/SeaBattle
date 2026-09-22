//
//  PlayerData+Board.swift
//  SeaBattle
//
//  R0.4: the bridge between the rules core and the legacy `PlayerData`.
//
//  `PlayerData` is an @Observable class the old views read directly — they bind
//  to `cells[row][column].cellStatus`. Rather than rewrite those views (they are
//  deleted in R4.6 anyway), the shot rules now run on a `Board` projected out of
//  `PlayerData` and written straight back. The duplicated rule code disappears;
//  the views keep seeing exactly the arrays they always saw.
//
//  THIS FILE IS TEMPORARY. When the redesigned screens bind to `Board` directly,
//  both this projection and `PlayerData` itself go away.
//

import Foundation

extension PlayerData {

    // MARK: - Legacy -> core

    /// This side's field as the rules core sees it.
    ///
    /// The two representations store ship knowledge differently: the legacy
    /// `cells` array only marks `.showShip` on YOUR board — the opponent's ships
    /// live solely in `ships` and their cells read `.unknown` so they stay
    /// hidden. The projection therefore takes ship positions from `ships` and
    /// overlays whatever has already been discovered from `cells`, which keeps
    /// both boards complete.
    var coreBoard: Board {
        var board = Board(ships: ships.map(\.corePlacement))
        for coordinate in Board.allCoordinates {
            let legacy = cells[coordinate.row - 1][coordinate.column - 1]
            switch legacy.cellStatus {
            case .unknown, .showShip, .showShipHalo:
                // Untouched. Whether a ship is there is already set by `init`.
                break
            case .missed:
                board[coordinate] = .miss
            case .onFire, .showShipOnFire:
                board[coordinate] = .hit
            case .destroyed:
                board[coordinate] = .sunk
            }
        }
        return board
    }

    // MARK: - Core -> legacy

    /// Writes a core board back into the legacy arrays.
    ///
    /// `.ship` becomes a visible hull on your own board and stays hidden on the
    /// opponent's — that is the only place the two sides are treated
    /// differently, and it is presentation, not rules.
    func apply(_ board: Board) {
        let showsOwnShips = side == .you
        for coordinate in Board.allCoordinates {
            let row = coordinate.row - 1
            let column = coordinate.column - 1
            let state = board[coordinate]
            let status: Cell.CurrentStatus
            switch state {
            case .water: status = .unknown
            case .miss:  status = .missed
            case .ship:  status = showsOwnShips ? .showShip : .unknown
            case .hit:   status = showsOwnShips ? .showShipOnFire : .onFire
            case .sunk:  status = .destroyed
            }
            if cells[row][column].cellStatus != status {
                cells[row][column].cellStatus = status
            }
            // In battle "available" means "not yet fired at". The arrangement
            // screen uses the same flag as its own scratch space and resets it
            // itself, so it is only maintained here for cells that were shot.
            let available = state.isUnshot
            if cells[row][column].isAvailable != available {
                cells[row][column].isAvailable = available
            }
        }
        syncSunkFlags(with: board)
    }

    /// Mirrors each ship's sunk state onto the legacy `Ship.isDestroyed` flag,
    /// which the score readouts count.
    private func syncSunkFlags(with board: Board) {
        for index in ships.indices {
            let cells = ships[index].coordinates.map { Coordinate(row: $0.0, column: $0.1) }
            // A ship can sit off the board mid-drag on the arrangement screen.
            let destroyed = !cells.isEmpty
                && cells.allSatisfy { $0.isOnBoard && board[$0] == .sunk }
            if ships[index].isDestroyed != destroyed {
                ships[index].isDestroyed = destroyed
            }
        }
    }
}

// MARK: - Ship <-> ShipPlacement

extension Ship {
    /// The core's view of this ship. The legacy type stores every coordinate;
    /// the core derives them, so only the first cell and the orientation carry
    /// over. The `id` is preserved so the two stay matched up.
    var corePlacement: ShipPlacement {
        // Take the topmost / leftmost cell rather than trusting the stored
        // order, which the arrangement screen rebuilds and reverses.
        let origin = Coordinate(row: coordinates.map(\.0).min() ?? 1,
                                column: coordinates.map(\.1).min() ?? 1)
        return ShipPlacement(id: id,
                             length: numberOfDecks,
                             origin: origin,
                             orientation: orientation == .horizontal ? .horizontal : .vertical)
    }
}
