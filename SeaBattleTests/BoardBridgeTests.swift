//
//  BoardBridgeTests.swift
//  SeaBattleTests
//
//  R0.4: all three modes now resolve shots on the rules core and write the
//  result back into the legacy `PlayerData` arrays the old views read. The
//  projection in both directions is the risky part of that migration, so it is
//  pinned down here — together with the guarantee that the AI cannot see the
//  fleet it is hunting for, and with a whole match played through each of the
//  three modes.
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
        // Firing AT the opponent's board never hands the turn to the computer.
        #expect(appState.enemysTurn)

        let empty = Board.allCoordinates.first { enemy.coreBoard[$0] == .water }!
        let miss = engine.checkShipOnFire(row: empty.row, column: empty.column, target: enemy)
        #expect(miss == .miss)
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

// MARK: - Hot seat

@MainActor
struct HotSeatMatchTests {

    /// A session with both fleets placed and the first player ready to shoot.
    private func shootingGame() -> HotSeatGame {
        let game = HotSeatGame()
        game.soundOn = false
        game.begin(name0: "A", avatar0: "a", color0: 0, pin0: "",
                   name1: "B", avatar1: "b", color1: 1, pin1: "")
        game.finishArrangement(player: 0)
        game.unlockArrange(player: 1)
        game.finishArrangement(player: 1)
        game.startShooting()
        return game
    }

    @Test("Hitting keeps the turn, missing offers it to the other player")
    func outcomesMatchTheCore() {
        let game = shootingGame()
        let defender = game.boards[game.defender]

        let shipCell = defender.ships.first { $0.numberOfDecks > 1 }!.coordinates[0]
        #expect(game.fire(row: shipCell.0, column: shipCell.1) == .hit)
        #expect(game.attacker == 0, "A hit must not pass the turn on its own")

        let empty = Board.allCoordinates.first { defender.coreBoard[$0] == .water }!
        #expect(game.fire(row: empty.row, column: empty.column) == .missed)
        // The view, not the model, advances the turn once the animation is done.
        game.passTurn()
        #expect(game.attacker == 1)
    }

    @Test("A one-deck ship sinks on the first hit")
    func sinkingReportsSunk() {
        let game = shootingGame()
        let single = game.boards[game.defender].ships.first { $0.numberOfDecks == 1 }!
        let cell = single.coordinates[0]

        #expect(game.fire(row: cell.0, column: cell.1) == .sunk)
        #expect(game.boards[game.defender].numberShipsDestroyed == 1)
    }

    @Test("Firing at the same cell twice is refused")
    func repeatShotIsRefused() {
        let game = shootingGame()
        let empty = Board.allCoordinates.first {
            game.boards[game.defender].coreBoard[$0] == .water
        }!

        #expect(game.fire(row: empty.row, column: empty.column) == .missed)
        #expect(game.canFire(row: empty.row, column: empty.column) == false)
        #expect(game.fire(row: empty.row, column: empty.column) == nil)
    }

    @Test("Auto-reveal marks the ring, and stays off by default")
    func revealAroundSunkIsOptional() {
        for reveal in [false, true] {
            let game = shootingGame()
            game.revealAroundSunk = reveal
            let defender = game.boards[game.defender]
            let victim = defender.ships.first { $0.numberOfDecks == 1 }!

            game.fire(row: victim.coordinates[0].0, column: victim.coordinates[0].1)

            let board = defender.coreBoard
            let ring = victim.corePlacement.ring
            #expect(!ring.isEmpty)
            if reveal {
                #expect(ring.allSatisfy { board[$0] == .miss })
            } else {
                #expect(ring.contains { board[$0] != .miss })
            }
        }
    }

    @Test("Sinking the last ship wins the session game")
    func wholeMatchCanBePlayed() {
        let game = shootingGame()
        let defender = game.boards[game.defender]
        var last: HotSeatGame.ShotResult?

        // Fire only at hulls: every shot is a hit, so the turn never changes
        // hands and one player can finish the fleet in a single run.
        for cell in defender.ships.flatMap(\.coordinates) {
            last = game.fire(row: cell.0, column: cell.1) ?? last
        }

        #expect(last == .win)
        #expect(game.winner == 0)
        #expect(game.players[0].sessionWins == 1)
        #expect(defender.coreBoard.isFleetDestroyed)
        #expect(game.canFire(row: 1, column: 1) == false, "The match is over")
    }

    @Test("The defender's board never gives its fleet away")
    func defenderBoardIsMasked() {
        // Both hot-seat boards store their owner's hulls, so the mask the grid
        // applies is the only thing keeping them secret from the shooter.
        #expect(HotSeatBoardGrid.masked(.showShip) == .unknown)
        #expect(HotSeatBoardGrid.masked(.showShipHalo) == .unknown)
        #expect(HotSeatBoardGrid.masked(.showShipOnFire) == .onFire)
        // Public information passes through untouched.
        #expect(HotSeatBoardGrid.masked(.missed) == .missed)
        #expect(HotSeatBoardGrid.masked(.destroyed) == .destroyed)
        #expect(HotSeatBoardGrid.masked(.onFire) == .onFire)
        #expect(HotSeatBoardGrid.masked(.unknown) == .unknown)
    }
}

// MARK: - Network

@MainActor
struct NetworkMatchTests {

    /// Two connected games, both fleets placed, host to shoot first.
    ///
    /// Both peers use the same account id on purpose: a same-account match
    /// awards no points, so the tests never touch the real `ProgressStore`.
    private func connectedPair() -> (host: NetworkGame, guest: NetworkGame, hostWire: LoopbackTransport) {
        let (a, b) = LoopbackTransport.pair()
        let host = NetworkGame(transport: a, statKey: .nearby, name: "H", avatar: "h",
                               accountID: "same", isHost: true)
        let guest = NetworkGame(transport: b, statKey: .nearby, name: "G", avatar: "g",
                                accountID: "same", isHost: false)
        host.soundOn = false
        guest.soundOn = false
        host.start()
        guest.start()
        host.confirmReady()
        guest.confirmReady()
        return (host, guest, a)
    }

    @Test("Both peers agree on a hit, and the shooter keeps the turn")
    func hitIsAgreedOn() {
        let (host, guest, _) = connectedPair()
        #expect(host.phase == .myTurn)

        let target = guest.own.ships.first { $0.numberOfDecks > 1 }!.coordinates[0]
        host.fire(row: target.0, column: target.1)

        let cell = Coordinate(row: target.0, column: target.1)
        #expect(guest.own.coreBoard[cell] == .hit, "The defender records the damage")
        #expect(host.tracking.coreBoard[cell] == .hit, "The shooter learns about it")
        #expect(host.phase == .myTurn, "A hit keeps the turn")
        #expect(guest.phase == .theirTurn)
    }

    @Test("A miss hands the turn over on both devices")
    func missPassesTheTurn() {
        let (host, guest, _) = connectedPair()
        let empty = Board.allCoordinates.first { guest.own.coreBoard[$0] == .water }!

        host.fire(row: empty.row, column: empty.column)

        #expect(guest.own.coreBoard[empty] == .miss)
        #expect(host.tracking.coreBoard[empty] == .miss)
        #expect(host.phase == .theirTurn)
        #expect(guest.phase == .myTurn)
    }

    @Test("The shooter's own fleet is never sent over the wire")
    func trackingBoardHoldsNoFleet() {
        let (host, guest, _) = connectedPair()
        #expect(host.tracking.ships.isEmpty)
        #expect(guest.tracking.ships.isEmpty)
        // A tracked board with no fleet still counts sunk ships, by clusters.
        #expect(host.tracking.coreBoard.sunkShipCount == 0)
    }

    @Test("A sunk ship is revealed to the shooter and counted once")
    func sinkingRevealsTheWholeShip() {
        let (host, guest, _) = connectedPair()
        let victim = guest.own.ships.first { $0.numberOfDecks == 3 }!

        for cell in victim.coordinates {
            host.fire(row: cell.0, column: cell.1)
        }

        #expect(host.opponentShipsSunk == 1)
        for cell in victim.coordinates {
            #expect(host.tracking.coreBoard[Coordinate(cell)] == .sunk)
        }
    }

    @Test("A whole networked match ends with both peers agreeing who won")
    func wholeMatchCanBePlayed() {
        let (host, guest, _) = connectedPair()

        // Hulls only, so the host keeps the turn all the way through.
        for cell in guest.own.ships.flatMap(\.coordinates) {
            host.fire(row: cell.0, column: cell.1)
        }

        #expect(host.iWon == true)
        #expect(guest.iWon == false)
        #expect(host.phase == .finished)
        #expect(guest.phase == .finished)
        #expect(host.opponentShipsSunk == FleetLayout.shipCount)
        #expect(guest.own.coreBoard.isFleetDestroyed)
    }

    @Test("A repeated shot is ignored rather than answered twice")
    func repeatedShotIsIgnored() {
        let (host, guest, hostWire) = connectedPair()
        let empty = Board.allCoordinates.first { guest.own.coreBoard[$0] == .water }!

        host.fire(row: empty.row, column: empty.column)
        let boardAfterFirstShot = guest.own.coreBoard
        // The host would never re-send this; a faulty or hostile peer might.
        hostWire.send(.fire(empty))

        #expect(guest.own.coreBoard == boardAfterFirstShot)
        #expect(guest.phase == .myTurn, "Answering again would steal the turn back")
    }
}
