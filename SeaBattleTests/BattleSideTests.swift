//
//  BattleSideTests.swift
//  SeaBattleTests
//
//  30.10: the match against the computer keeps each side as a `Board` in a
//  `BattleSide` (it used to be the legacy `PlayerData` with a projection to the
//  core and back — those round-trip tests went with it). Pinned down here: what
//  a side holds, the guarantee that the AI cannot see the fleet it is hunting
//  for, and a whole match played against the computer.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct BattleSideTests {

    @Test("A side knows its role and starts empty")
    func aSideStartsEmpty() {
        for side in Side.allCases {
            let battleSide = BattleSide(side: side)
            #expect(battleSide.side == side)
            #expect(battleSide.board.ships.isEmpty)
            #expect(Board.allCoordinates.allSatisfy { battleSide.board[$0] == .water })
        }
    }

    @Test("Placing a fleet keeps every ship and marks its cells")
    func placingKeepsTheFleet() {
        let battleSide = BattleSide(side: .you)
        let layout = FleetLayout.canonicalLayout()
        battleSide.place(layout)

        #expect(battleSide.board.ships == layout)
        let shipCells = Set(layout.flatMap(\.cells))
        #expect(shipCells.count == FleetLayout.occupiedCellCount)
        for coordinate in Board.allCoordinates {
            #expect(battleSide.board[coordinate] == (shipCells.contains(coordinate) ? .ship : .water))
        }
    }

    @Test("A random fleet is a legal full fleet")
    func aRandomFleetIsLegal() {
        let battleSide = BattleSide(side: .foe)
        battleSide.randomFleet()
        #expect(battleSide.board.ships.map(\.length).sorted(by: >) == FleetLayout.deckCounts)
        #expect(FleetLayout.conflicts(in: battleSide.board.ships).isEmpty)
    }

    @Test("The score counts sunk ships; a reset clears the field")
    func scoreAndReset() {
        let battleSide = BattleSide(side: .foe)
        battleSide.place(FleetLayout.canonicalLayout())
        var board = battleSide.board
        let victim = board.ships[0]
        for cell in victim.cells { board.apply(shotAt: cell) }
        battleSide.board = board
        #expect(battleSide.sunkShipCount == 1)

        battleSide.reset()
        #expect(battleSide.sunkShipCount == 0)
        #expect(battleSide.board.ships.isEmpty)
    }
}

@MainActor
struct FogOfWarTests {

    @Test("The opponent's view hides unharmed ships but keeps public damage")
    func opponentViewMasksShips() {
        var board = Board(ships: FleetLayout.canonicalLayout())
        let victim = board.ships[0]
        for cell in victim.cells { board.apply(shotAt: cell) }       // sunk
        let survivor = board.ships[1]
        board.apply(shotAt: survivor.cells[0])                        // hit, afloat
        board.apply(shotAt: Coordinate(row: 10, column: 1))           // miss

        let view = board.opponentView()

        #expect(view.ships.isEmpty)
        #expect(!Board.allCoordinates.contains { view[$0] == .ship })
        #expect(view[survivor.cells[0]] == .hit)
        #expect(victim.cells.allSatisfy { view[$0] == .sunk })
        #expect(view[row: 10, column: 1] == .miss)
        // The rest of the survivor is back to looking like open water.
        #expect(view[survivor.cells[1]] == .water)
    }

    @Test("Hidden ship cells are still shootable in the masked view")
    func maskedCellsStayShootable() {
        let board = Board(ships: FleetLayout.canonicalLayout())
        #expect(board.opponentView().shootableCells().count == 100)
    }
}

@MainActor
struct VsComputerMatchTests {

    private func configuredGame() -> (AppState, BattleSide, BattleSide, GameEngine) {
        let appState = AppState()
        let player = BattleSide(side: .you)
        let enemy = BattleSide(side: .foe)
        player.randomFleet()
        enemy.randomFleet()
        appState.gameIsActive = true
        let engine = GameEngine()
        engine.configure(appState: appState, player: player, enemy: enemy)
        return (appState, player, enemy, engine)
    }

    @Test("A hit keeps the turn, a miss hands it over")
    func turnFollowsTheResult() {
        let (appState, _, enemy, engine) = configuredGame()
        let shipCell = enemy.board.ships[0].cells[0]

        let hit = engine.checkShipOnFire(row: shipCell.row, column: shipCell.column, target: enemy)
        #expect(hit.isHit)
        // A hit on the opponent's board keeps the turn with the player. Until
        // R2.3 this line expected the opposite, and the game really did hand
        // the turn over after every hit.
        #expect(!appState.enemysTurn)

        let empty = Board.allCoordinates.first { enemy.board[$0] == .water }!
        let miss = engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)
        #expect(miss == .miss)
        #expect(appState.enemysTurn)
    }

    @Test("The computer keeps the turn while it hits and loses it on a miss")
    func computerTurnFollowsTheResult() {
        let (appState, player, _, engine) = configuredGame()
        appState.enemysTurn = true
        let shipCell = player.board.ships[0].cells[0]

        engine.checkShipOnFire(row: shipCell.row, column: shipCell.column, target: player)
        #expect(appState.enemysTurn)

        let empty = Board.allCoordinates.first { player.board[$0] == .water }!
        engine.checkShipOnFire(row: empty.row, column: empty.column, target: player)
        #expect(!appState.enemysTurn)
    }

    @Test("A repeat shot leaves the board untouched")
    func repeatShotIsInert() {
        let (_, _, enemy, engine) = configuredGame()
        let empty = Board.allCoordinates.first { enemy.board[$0] == .water }!

        engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)
        let before = enemy.board
        let again = engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)

        #expect(again == .repeated(.miss))
        #expect(enemy.board == before)
    }

    @Test("Sinking the whole fleet ends the match")
    func matchEnds() {
        let (appState, _, enemy, engine) = configuredGame()
        for coordinate in Board.allCoordinates {
            engine.checkShipOnFire(row: coordinate.row, column: coordinate.column, target: enemy)
        }
        #expect(enemy.sunkShipCount == FleetLayout.shipCount)
        #expect(!appState.gameIsActive)
        #expect(appState.gameIsOver)
    }

    @Test("Auto-reveal marks the ring around a sunk opponent ship")
    func autoRevealFillsTheRing() {
        let (appState, _, enemy, engine) = configuredGame()
        appState.autoRevealAroundSunk = true

        let victim = enemy.board.ships[0]
        for cell in victim.cells {
            engine.checkShipOnFire(row: cell.row, column: cell.column, target: enemy)
        }
        for cell in victim.ring where cell.isOnBoard {
            #expect(enemy.board[cell] == .miss)
        }
    }

    @Test("The computer never fires at a cell it has already tried", arguments: 0..<20)
    func computerPlaysAWholeMatchWithoutRepeating(_ iteration: Int) async {
        let (appState, player, enemy, engine) = configuredGame()
        let opponent = ComputerOpponent(appState: appState, ownFleet: enemy, targetBoard: player)

        var fired = Set<Coordinate>()
        // A full board is 100 cells; anything beyond that means it is repeating
        // itself or the match cannot finish.
        for _ in 0..<100 {
            let shot = await opponent.nextShot()
            #expect(!fired.contains(shot), "The computer fired at \(shot) twice")
            fired.insert(shot)
            engine.checkShipOnFire(row: shot.row, column: shot.column, target: player)
            if player.board.isFleetDestroyed { break }
        }
        #expect(player.board.isFleetDestroyed, "The computer failed to finish the fleet in 100 shots")
    }

    @Test("Every difficulty level can finish a match")
    func everyLevelFinishes() async {
        for (setting, level) in [(2, AppState.DifficultyLevel.easy),
                                 (1, .medium), (0, .hard), (3, .expert)] {
            let (appState, player, enemy, engine) = configuredGame()
            appState.difficulty = setting
            #expect(appState.difficultyLevel == level)
            let opponent = ComputerOpponent(appState: appState, ownFleet: enemy, targetBoard: player)

            for _ in 0..<100 {
                let shot = await opponent.nextShot()
                engine.checkShipOnFire(row: shot.row, column: shot.column, target: player)
                if player.board.isFleetDestroyed { break }
            }
            #expect(player.board.isFleetDestroyed, "\(level) failed to finish the fleet")
        }
    }
}

// Вдвоём на устройстве с R3.2 — `DuelGameTests`; сетевая партия с R3.3 — `NetGameTests`.
