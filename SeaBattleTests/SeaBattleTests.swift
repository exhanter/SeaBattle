//
//  SeaBattleTests.swift
//  SeaBattleTests
//
//  R0.2: the previous XCTest suite has not compiled since Phase 0 — it called
//  `checkShipIsTotallyDestroyed`, `definePriorityTargetCells` and
//  `findAvailableCellsForFire` on `GameLogicViewModel`, and those moved to
//  `GameEngine` / `ComputerOpponent` when the facade was introduced. It is
//  replaced here by Swift Testing coverage of what exists today; the real
//  rules-core suite arrives with R0.3 / R0.5, once the rules live in one place.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct BoardSetupTests {

    @Test("A fresh board is a 10 x 10 grid")
    func freshBoardIsTenByTen() {
        let player = PlayerData(name: "Player")
        #expect(player.cells.count == 10)
        #expect(player.cells.allSatisfy { $0.count == 10 })
    }

    @Test("fireStrokeArray is 10 x 10, not a growing triangle")
    func fireStrokeArrayIsRectangular() {
        // Regression (R0.2): both `PlayerData.init` and `AppState.resetData`
        // reused one accumulating array, so row N held (N + 1) * 10 entries.
        let player = PlayerData(name: "Player")
        #expect(player.fireStrokeArray.count == 10)
        #expect(player.fireStrokeArray.allSatisfy { $0.count == 10 })
        #expect(player.fireStrokeArray.allSatisfy { $0.allSatisfy { !$0 } })
    }

    @Test("resetData rebuilds both boards as 10 x 10")
    func resetDataRebuildsBothBoards() {
        let appState = AppState()
        let player = PlayerData(name: "Player")
        let enemy = PlayerData(name: "Enemy")
        player.shipsRandomArrangement()

        appState.resetData(player: player, enemy: enemy)

        for board in [player, enemy] {
            #expect(board.cells.count == 10)
            #expect(board.cells.allSatisfy { $0.count == 10 })
            #expect(board.fireStrokeArray.count == 10)
            #expect(board.fireStrokeArray.allSatisfy { $0.count == 10 })
        }
    }
}

@MainActor
struct FleetArrangementTests {

    /// The canonical fleet: one 4-deck, two 3-deck, three 2-deck, four 1-deck.
    private static let expectedDeckCounts = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]

    @Test("A random arrangement always places the full fleet", arguments: 0..<50)
    func placesTenShips(_ iteration: Int) {
        let player = PlayerData(name: "Player")
        player.shipsRandomArrangement()

        #expect(player.ships.count == 10)
        #expect(player.ships.map(\.numberOfDecks).sorted(by: >) == Self.expectedDeckCounts)
        // Ships are returned in canonical order so the manual-arrangement UI
        // can address them by `number`.
        #expect(player.ships.map(\.number) == Array(0..<10))
    }

    @Test("Ships never touch, not even diagonally", arguments: 0..<50)
    func shipsNeverTouch(_ iteration: Int) {
        let player = PlayerData(name: "Player")
        player.shipsRandomArrangement()

        var owner = [[Int?]](repeating: [Int?](repeating: nil, count: 10), count: 10)
        for ship in player.ships {
            for (row, column) in ship.coordinates {
                #expect((1...10).contains(row) && (1...10).contains(column))
                #expect(owner[row - 1][column - 1] == nil, "Two ships share a cell")
                owner[row - 1][column - 1] = ship.number
            }
        }

        for row in 0..<10 {
            for column in 0..<10 {
                guard let here = owner[row][column] else { continue }
                for dr in -1...1 {
                    for dc in -1...1 where dr != 0 || dc != 0 {
                        let nr = row + dr, nc = column + dc
                        guard (0..<10).contains(nr), (0..<10).contains(nc),
                              let neighbour = owner[nr][nc] else { continue }
                        #expect(neighbour == here, "Ships \(here) and \(neighbour) are adjacent")
                    }
                }
            }
        }
    }

    @Test("Every ship is a straight line matching its orientation", arguments: 0..<50)
    func shipsAreStraight(_ iteration: Int) {
        let player = PlayerData(name: "Player")
        player.shipsRandomArrangement()

        for ship in player.ships {
            #expect(ship.coordinates.count == ship.numberOfDecks)
            let rows = Set(ship.coordinates.map(\.0))
            let columns = Set(ship.coordinates.map(\.1))
            switch ship.orientation {
            case .horizontal:
                #expect(rows.count == 1)
                #expect(columns.count == ship.numberOfDecks)
            case .vertical:
                #expect(columns.count == 1)
                #expect(rows.count == ship.numberOfDecks)
            }
        }
    }

    @Test("The player's own board shows its ships after arranging")
    func playerBoardRevealsOwnShips() {
        let player = PlayerData(name: "Player")
        player.shipsRandomArrangement()

        let shipCells = player.ships.flatMap(\.coordinates)
        for (row, column) in shipCells {
            #expect(player.cells[row - 1][column - 1].cellStatus == .showShip)
        }
        // 4 + 3 + 3 + 2 + 2 + 2 + 1 + 1 + 1 + 1
        #expect(shipCells.count == 20)
    }
}

@MainActor
struct AudioServiceTests {

    @Test("Every effect maps to a bundled sound file", arguments: AudioService.Effect.allCases)
    func effectFilesExist(_ effect: AudioService.Effect) {
        #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "") != nil)
    }

    @Test("Unknown sound names are ignored rather than crashing")
    func unknownNameIsIgnored() {
        // The old call sites pass raw file names, including "" on paths where
        // no sound was chosen.
        AudioService.shared.play(named: "")
        AudioService.shared.play(named: "not_a_real_file.wav")
    }
}
