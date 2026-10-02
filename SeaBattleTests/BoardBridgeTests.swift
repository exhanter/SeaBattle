//
//  BoardBridgeTests.swift
//  SeaBattleTests
//
//  R0.4: all three modes now resolve shots on the rules core and write the
//  result back into the `PlayerData` arrays the computer match still keeps. The
//  projection in both directions is the risky part of that migration, so it is
//  pinned down here — together with the guarantee that the AI cannot see the
//  fleet it is hunting for, and with a whole match played against the computer.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct PlayerDataProjectionTests {

    private func arrangedPlayer(side: Side) -> PlayerData {
        let player = PlayerData(side: side)
        player.shipsRandomArrangement()
        return player
    }

    @Test("A side knows its role without comparing names")
    func sideReplacesNameComparison() {
        #expect(PlayerData(side: .you).name == "Player")
        #expect(PlayerData(side: .foe).name == "Enemy")
        #expect(PlayerData(name: "Player").side == .you)
        #expect(PlayerData(name: "Enemy").side == .foe)
    }

    @Test("Projecting your own board keeps the whole fleet")
    func ownBoardProjectsShips() {
        let player = arrangedPlayer(side: .you)
        let board = player.coreBoard

        #expect(board.ships.count == FleetLayout.shipCount)
        let shipCells = Set(player.ships.flatMap { $0.coordinates.map(Coordinate.init) })
        #expect(shipCells.count == FleetLayout.occupiedCellCount)
        for coordinate in shipCells {
            #expect(board[coordinate] == .ship)
        }
    }

    @Test("Projecting the opponent's board keeps the fleet even though the cells hide it")
    func foeBoardProjectsShipsFromTheFleet() {
        // The legacy arrays never mark `.showShip` on the opponent's board —
        // ship positions live only in `ships`. The projection has to recover
        // them, or every shot at the opponent would read as a miss.
        let foe = arrangedPlayer(side: .foe)
        #expect(foe.cells.allSatisfy { $0.allSatisfy { $0.cellStatus == .unknown } })

        let board = foe.coreBoard
        for coordinate in foe.ships.flatMap({ $0.coordinates.map(Coordinate.init) }) {
            #expect(board[coordinate] == .ship)
        }
    }

    @Test("Writing a board back and projecting it again changes nothing")
    func projectionRoundTrips() {
        for side in Side.allCases {
            let player = arrangedPlayer(side: side)
            var board = player.coreBoard

            // Scatter some history: a miss, a hit and a sunk ship.
            board.apply(shotAt: Coordinate(row: 1, column: 1))
            if let ship = board.ships.first(where: { $0.length > 1 }) {
                for cell in ship.cells { board.apply(shotAt: cell) }
            }
            if let other = board.ships.first(where: { $0.length == 1 }) {
                board.apply(shotAt: other.origin)
            }

            player.apply(board)
            #expect(player.coreBoard == board, "Round trip lost information on side \(side)")
        }
    }

    @Test("Your own hull shows; the opponent's stays hidden")
    func writeBackRespectsTheRole() {
        let you = arrangedPlayer(side: .you)
        let foe = arrangedPlayer(side: .foe)

        you.apply(you.coreBoard)
        foe.apply(foe.coreBoard)

        let yourShipCell = you.ships[0].coordinates[0]
        #expect(you.cells[yourShipCell.0 - 1][yourShipCell.1 - 1].cellStatus == .showShip)

        let foeShipCell = foe.ships[0].coordinates[0]
        #expect(foe.cells[foeShipCell.0 - 1][foeShipCell.1 - 1].cellStatus == .unknown)
    }

    @Test("Damage maps onto the legacy statuses each side expects")
    func writeBackMapsDamage() {
        let you = arrangedPlayer(side: .you)
        let foe = arrangedPlayer(side: .foe)

        for (player, hitStatus) in [(you, Cell.CurrentStatus.showShipOnFire),
                                    (foe, Cell.CurrentStatus.onFire)] {
            var board = player.coreBoard
            let longest = board.ships.max { $0.length < $1.length }!
            board.apply(shotAt: longest.cells[0])          // hit, still afloat
            board.apply(shotAt: Coordinate(row: 10, column: 10)) // probably a miss
            player.apply(board)

            let hit = longest.cells[0]
            #expect(player.cells[hit.row - 1][hit.column - 1].cellStatus == hitStatus)
            #expect(!player.cells[hit.row - 1][hit.column - 1].isAvailable)
        }
    }

    @Test("Sinking a ship flips the legacy isDestroyed flag the score reads")
    func writeBackSyncsSunkFlags() {
        let foe = arrangedPlayer(side: .foe)
        var board = foe.coreBoard
        let victim = board.ships[0]
        for cell in victim.cells { board.apply(shotAt: cell) }
        foe.apply(board)

        #expect(foe.numberShipsDestroyed == 1)
        #expect(foe.ships.first { $0.id == victim.id }?.isDestroyed == true)
        #expect(foe.ships.filter { !$0.isDestroyed }.count == FleetLayout.shipCount - 1)
        for cell in victim.cells {
            #expect(foe.cells[cell.row - 1][cell.column - 1].cellStatus == .destroyed)
        }
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

    private func configuredGame() -> (AppState, PlayerData, PlayerData, GameEngine) {
        let appState = AppState()
        let player = PlayerData(side: .you)
        let enemy = PlayerData(side: .foe)
        player.shipsRandomArrangement()
        enemy.shipsRandomArrangement()
        appState.gameIsActive = true
        let engine = GameEngine()
        engine.configure(appState: appState, player: player, enemy: enemy)
        return (appState, player, enemy, engine)
    }

    @Test("A hit keeps the turn, a miss hands it over")
    func turnFollowsTheResult() {
        let (appState, _, enemy, engine) = configuredGame()
        let shipCell = enemy.ships[0].coordinates[0]

        let hit = engine.checkShipOnFire(row: shipCell.0, column: shipCell.1, target: enemy)
        #expect(hit.isHit)
        // A hit on the opponent's board keeps the turn with the player. Until
        // R2.3 this line expected the opposite, and the game really did hand
        // the turn over after every hit.
        #expect(!appState.enemysTurn)

        let empty = Board.allCoordinates.first { enemy.coreBoard[$0] == .water }!
        let miss = engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)
        #expect(miss == .miss)
        #expect(appState.enemysTurn)
    }

    @Test("The computer keeps the turn while it hits and loses it on a miss")
    func computerTurnFollowsTheResult() {
        let (appState, player, _, engine) = configuredGame()
        appState.enemysTurn = true
        let shipCell = player.ships[0].coordinates[0]

        engine.checkShipOnFire(row: shipCell.0, column: shipCell.1, target: player)
        #expect(appState.enemysTurn)

        let empty = Board.allCoordinates.first { player.coreBoard[$0] == .water }!
        engine.checkShipOnFire(row: empty.row, column: empty.column, target: player)
        #expect(!appState.enemysTurn)
    }

    @Test("A repeat shot leaves the board untouched")
    func repeatShotIsInert() {
        let (_, _, enemy, engine) = configuredGame()
        let empty = Board.allCoordinates.first { enemy.coreBoard[$0] == .water }!

        engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)
        let before = enemy.coreBoard
        let again = engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)

        #expect(again == .repeated(.miss))
        #expect(enemy.coreBoard == before)
    }

    @Test("Sinking the whole fleet ends the match")
    func matchEnds() {
        let (appState, _, enemy, engine) = configuredGame()
        for coordinate in Board.allCoordinates {
            engine.checkShipOnFire(row: coordinate.row, column: coordinate.column, target: enemy)
        }
        #expect(enemy.numberShipsDestroyed == FleetLayout.shipCount)
        #expect(!appState.gameIsActive)
        #expect(appState.gameIsOver)
    }

    @Test("Auto-reveal marks the ring around a sunk opponent ship")
    func autoRevealFillsTheRing() {
        let (appState, _, enemy, engine) = configuredGame()
        appState.autoRevealAroundSunk = true

        let victim = enemy.ships[0]
        for cell in victim.coordinates {
            engine.checkShipOnFire(row: cell.0, column: cell.1, target: enemy)
        }
        for cell in victim.corePlacement.ring {
            #expect(enemy.cells[cell.row - 1][cell.column - 1].cellStatus == .missed)
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
            if player.coreBoard.isFleetDestroyed { break }
        }
        #expect(player.coreBoard.isFleetDestroyed, "The computer failed to finish the fleet in 100 shots")
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
                if player.coreBoard.isFleetDestroyed { break }
            }
            #expect(player.coreBoard.isFleetDestroyed, "\(level) failed to finish the fleet")
        }
    }
}

// Вдвоём на устройстве с R3.2 — `DuelGameTests`; сетевая партия с R3.3 — `NetGameTests`.
