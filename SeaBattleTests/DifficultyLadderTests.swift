//
//  DifficultyLadderTests.swift
//  SeaBattleTests
//
//  R0.6: the four difficulty levels used to be three copies of the same code
//  plus one small exception (audit finding A6). Now each adds one idea to the
//  one below it, so what is worth testing is not "does it fire somewhere" but
//  the difference between the levels — both the rule each one follows and the
//  fact that it actually makes the computer harder to beat.
//
//  `ComputerOpponent.targetCandidates(on:)` is asked directly: it is a pure
//  function of the board, so a level's reasoning can be inspected without
//  firing a shot or waiting for a turn.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct DifficultyLadderTests {

    // MARK: - Fixtures

    /// The four levels are stored as magic integers in `AppState.difficulty`
    /// (audit finding C14, still open), so the mapping is spelled out once here
    /// and checked, rather than assumed at every call site.
    private static let settings: [(level: AppState.DifficultyLevel, difficulty: Int)] = [
        (.easy, 2), (.medium, 1), (.hard, 0), (.expert, 3)
    ]

    private func opponent(at level: AppState.DifficultyLevel) -> ComputerOpponent {
        let appState = AppState()
        appState.difficulty = Self.settings.first { $0.level == level }!.difficulty
        #expect(appState.difficultyLevel == level, "The difficulty mapping moved")
        return ComputerOpponent(appState: appState,
                                ownFleet: PlayerData(side: .foe),
                                targetBoard: PlayerData(side: .you))
    }

    /// The canonical fleet as the shooter sees it, with `shots` already fired.
    private func maskedBoard(afterShotsAt shots: [Coordinate] = []) -> Board {
        var board = Board(ships: FleetLayout.canonicalLayout())
        for shot in shots { board.apply(shotAt: shot) }
        return board.opponentView()
    }

    private var allLevels: [AppState.DifficultyLevel] { Self.settings.map(\.level) }

    // MARK: - What each level does with damage

    @Test("EVERY level follows up on a damaged ship, easy included")
    func allLevelsFinishWhatTheyStarted() {
        // One hit on the four-decker at (1,1)-(1,4); it is still afloat.
        //
        // Even easy does this. A computer that hits a ship and then wanders off
        // reads as broken rather than as easy, and it is not needed: easy is
        // already a giveaway (about one match in a hundred) from not knowing
        // that ships never touch.
        let board = maskedBoard(afterShotsAt: [Coordinate(row: 1, column: 2)])
        let neighbours = Set(Coordinate(row: 1, column: 2).orthogonalNeighbours)

        for level in allLevels {
            let candidates = opponent(at: level).targetCandidates(on: board)
            #expect(!candidates.isEmpty)
            #expect(candidates.allSatisfy { neighbours.contains($0) },
                    "\(level) considered \(candidates) instead of probing the hit")
        }
    }

    @Test("Two hits in a row fix the orientation, so only the ends are tried")
    func linesAreExtendedNotProbedSideways() {
        let board = maskedBoard(afterShotsAt: [Coordinate(row: 1, column: 2),
                                               Coordinate(row: 1, column: 3)])
        let ends: Set<Coordinate> = [Coordinate(row: 1, column: 1), Coordinate(row: 1, column: 4)]

        for level in allLevels {
            let candidates = Set(opponent(at: level).targetCandidates(on: board))
            #expect(candidates == ends,
                    "\(level) fired sideways off a known line: \(candidates)")
        }
    }

    // MARK: - What each level does with a sunk ship

    @Test("Only easy fails to notice that ships never touch")
    func onlyEasyIgnoresTheNoTouchingRule() {
        // Sink the single-deck ship at (5,4) outright.
        let victim = Coordinate(row: 5, column: 4)
        let board = maskedBoard(afterShotsAt: [victim])
        #expect(board[victim] == .sunk)
        let ring = Set(victim.neighbours)

        for level in [AppState.DifficultyLevel.medium, .hard, .expert] {
            let candidates = Set(opponent(at: level).targetCandidates(on: board))
            #expect(candidates.isDisjoint(with: ring),
                    "\(level) still considers cells that cannot hold a ship")
        }
        // Easy keeps wasting shots there, and that single blind spot is most of
        // what makes it easy: it is worth about thirty shots a match, more than
        // everything the three levels above it know put together.
        let easy = Set(opponent(at: .easy).targetCandidates(on: board))
        #expect(!easy.isDisjoint(with: ring),
                "Easy is not supposed to know that ships never touch")
    }

    @Test("Finishing a damaged ship never fires into the ring around a sunk one")
    func finishingRespectsTheNoTouchingRule() {
        // A one-decker at (3,3) and a three-decker at (5,3)-(7,3): the cell
        // (4,3) between them is in the sunk ring and cannot be the rest of the
        // three-decker. Before 05.10 finishing ignored that on every level.
        let single = Coordinate(row: 3, column: 3)
        let ringCell = Coordinate(row: 4, column: 3)
        var board = Board(ships: [
            ShipPlacement(length: 1, origin: single, orientation: .horizontal),
            ShipPlacement(length: 3, origin: Coordinate(row: 5, column: 3), orientation: .vertical),
        ])
        board.apply(shotAt: single)
        board.apply(shotAt: Coordinate(row: 5, column: 3))
        let lone = board.opponentView()
        board.apply(shotAt: Coordinate(row: 6, column: 3))
        let line = board.opponentView()

        for level in [AppState.DifficultyLevel.medium, .hard, .expert] {
            let probes = Set(opponent(at: level).targetCandidates(on: lone))
            #expect(probes == [Coordinate(row: 5, column: 2), Coordinate(row: 5, column: 4),
                               Coordinate(row: 6, column: 3)],
                    "\(level) probed \(probes)")
            let ends = opponent(at: level).targetCandidates(on: line)
            #expect(ends == [Coordinate(row: 7, column: 3)],
                    "\(level) extended the line to \(ends)")
        }
        // Easy still does not know the rule.
        #expect(opponent(at: .easy).targetCandidates(on: line).contains(ringCell))
    }

    @Test("A probe around one damaged ship never lands diagonal to another")
    func probesAvoidTheDiagonalsOfOtherHits() {
        // Two damaged two-deckers: (5,5)-(5,6) and (7,4)-(8,4), one hit each.
        // (6,4) is next to the second hit but diagonal to the first, so no
        // ship can be there.
        var board = Board(ships: [
            ShipPlacement(length: 2, origin: Coordinate(row: 5, column: 5), orientation: .horizontal),
            ShipPlacement(length: 2, origin: Coordinate(row: 7, column: 4), orientation: .vertical),
        ])
        board.apply(shotAt: Coordinate(row: 5, column: 5))
        board.apply(shotAt: Coordinate(row: 7, column: 4))
        let masked = board.opponentView()

        for level in [AppState.DifficultyLevel.medium, .hard, .expert] {
            let probes = Set(opponent(at: level).targetCandidates(on: masked))
            #expect(!probes.contains(Coordinate(row: 6, column: 4)),
                    "\(level) probed a cell diagonal to another hit: \(probes)")
            #expect(!probes.isEmpty)
        }
    }

    // MARK: - Hard: the checkerboard

    @Test("Hard hunts one colour of the board while a multi-deck ship is afloat")
    func hardUsesTheCheckerboard() {
        let board = maskedBoard()
        let candidates = opponent(at: .hard).targetCandidates(on: board)

        #expect(candidates.count == Board.cellCount / 2)
        #expect(candidates.allSatisfy { ($0.row + $0.column).isMultiple(of: 2) })
    }

    @Test("Hard drops the checkerboard once only single-deck ships are left")
    func hardDropsThePatternForTheEndgame() {
        var board = Board(ships: FleetLayout.canonicalLayout())
        for ship in board.ships where ship.length >= 2 {
            for cell in ship.cells { board.apply(shotAt: cell) }
        }
        let masked = board.opponentView()
        #expect(masked.remainingShipLengths().allSatisfy { $0 == 1 })

        let candidates = opponent(at: .hard).targetCandidates(on: masked)
        // A single-deck ship fits between the cells of a checkerboard, so
        // sticking to one colour could never finish the match.
        #expect(candidates.contains { !($0.row + $0.column).isMultiple(of: 2) },
                "Hard would never be able to find the last single-deck ships")
    }

    @Test("The other levels ignore the checkerboard")
    func onlyHardUsesThePattern() {
        let board = maskedBoard()
        for level in [AppState.DifficultyLevel.easy, .medium] {
            let candidates = opponent(at: level).targetCandidates(on: board)
            #expect(candidates.count == Board.cellCount,
                    "\(level) should consider the whole untouched board")
        }
    }

    // MARK: - Expert: the heat map

    @Test("Expert commits to a single best cell rather than a set")
    func expertPicksThePeak() {
        let board = maskedBoard()
        let candidates = opponent(at: .expert).targetCandidates(on: board)

        #expect(candidates.count == 1)
        // The four-decker fits through the middle in the most ways, so the peak
        // is never on the edge of an untouched board.
        let peak = candidates[0]
        #expect((2...9).contains(peak.row))
        #expect((2...9).contains(peak.column))
    }

    // MARK: - Does the ladder actually climb?

    /// One match against the given fleet. RETURNS the shots the computer needed
    /// to sink every ship of two or more decks, and to clear the board.
    ///
    /// The multi-deck figure is the interesting one. Clearing the whole board
    /// barely separates the levels, and that is the game, not the code: the
    /// four single-deck ships are invisible to any amount of cleverness — a
    /// lone cell in open water leaves nothing to reason from — and hunting them
    /// down is most of a match. Sinking the six ships that CAN be reasoned
    /// about is where a level shows what it knows.
    private func shotsNeeded(against fleet: [Ship],
                             at level: AppState.DifficultyLevel) async -> (multiDeck: Int, total: Int)? {
        let appState = AppState()
        appState.difficulty = Self.settings.first { $0.level == level }!.difficulty

        let target = PlayerData(side: .you)
        target.ships = fleet
        target.apply(Board(ships: fleet.map(\.corePlacement)))

        let computer = ComputerOpponent(appState: appState,
                                        ownFleet: PlayerData(side: .foe),
                                        targetBoard: target)
        var multiDeck: Int?
        for shot in 1...Board.cellCount {
            let coordinate = await computer.nextShot()
            var board = target.coreBoard
            board.apply(shotAt: coordinate)
            target.apply(board)

            if multiDeck == nil,
               board.ships.filter({ $0.length >= 2 }).allSatisfy({ board.isSunk($0) }) {
                multiDeck = shot
            }
            if board.isFleetDestroyed { return (multiDeck ?? shot, shot) }
        }
        return nil
    }

    /// One random fleet per match, and every level plays the SAME fleets.
    ///
    /// Paired on purpose: which fleet you get swings a match by far more than
    /// the level does, so comparing four levels on four different sets of
    /// fleets mostly measures the luck of the draw.
    private func averageShotsPerLevel(matches: Int = 100) async
    -> [AppState.DifficultyLevel: (multiDeck: Double, total: Double)] {
        let fleets: [[Ship]] = (0..<matches).map { _ in
            let scratch = PlayerData(side: .you)
            scratch.shipsRandomArrangement()
            return scratch.ships
        }

        var totals: [AppState.DifficultyLevel: (multiDeck: Int, total: Int)] = [:]
        for fleet in fleets {
            for (level, _) in Self.settings {
                guard let shots = await shotsNeeded(against: fleet, at: level) else {
                    Issue.record("\(level) failed to clear a fleet in \(Board.cellCount) shots")
                    continue
                }
                let running = totals[level] ?? (0, 0)
                totals[level] = (running.multiDeck + shots.multiDeck,
                                 running.total + shots.total)
            }
        }
        return totals.mapValues { (Double($0.multiDeck) / Double(matches),
                                   Double($0.total) / Double(matches)) }
    }

    @Test("Each level sinks the reasonable half of the fleet faster than the one below it")
    func theLadderClimbs() async {
        let average = await averageShotsPerLevel()
        let easy = average[.easy]!
        let medium = average[.medium]!
        let hard = average[.hard]!
        let expert = average[.expert]!
        func line(_ name: String, _ shots: (multiDeck: Double, total: Double)) -> String {
            let multiDeck = String(format: "%5.2f", shots.multiDeck)
            let total = String(format: "%5.2f", shots.total)
            return "  \(name.padding(toLength: 7, withPad: " ", startingAt: 0)) \(multiDeck)   \(total)"
        }
        // Printed on every run, not only on failure: the numbers are the whole
        // argument for how the levels are built, and they are worth seeing
        // again whenever the targeting is touched.
        let text = """
            Difficulty ladder, 100 fleets, each level playing the same ones.
            Average shots to sink the six multi-deck ships / to clear the board:
            \(line("easy", easy))
            \(line("medium", medium))
            \(line("hard", hard))
            \(line("expert", expert))
            """
        print(text)
        let report = Comment(rawValue: text)

        // Clearing the whole board is what decides a real match, so that is the
        // column the ladder has to be monotone in. It is also the harder test:
        // an early version of `.hard` beat medium to the multi-deck ships and
        // still lost the match on total shots, because sweeping one colour of
        // the board leaves the single-deck ships hidden for the endgame.
        // THIS TEST ONLY MEASURES ATTACK. Measured at roughly 88 · 59 · 58 · 56
        // shots to clear the board, so the only large step here is easy to
        // medium — knowing that ships never touch is worth about thirty shots.
        // Everything above that is worth a shot or two, because the levels are
        // already near the floor: the four single-deck ships are invisible to
        // any amount of cleverness, and hunting them down is most of a match.
        //
        // The step from medium to hard is DEFENCE, not attack — hard hides its
        // own fleet — and it does not show up here at all. The difficulty
        // ladder as a player experiences it is in `LadderWinRateTests`.
        #expect(medium.total < easy.total - 15, report)
        #expect(hard.total < medium.total + 2, report)
        #expect(expert.total < medium.total, report)

        // The multi-deck column separates the shooting more clearly: it is the
        // part of a match where reasoning can help at all.
        #expect(medium.multiDeck < easy.multiDeck - 10, report)
        #expect(hard.multiDeck < medium.multiDeck - 3, report)
        #expect(expert.multiDeck < hard.multiDeck, report)

        // Sanity: 16 cells belong to multi-deck ships, so nothing can sink them
        // in fewer than 16 shots, and easy is a random sweep of 100 cells.
        #expect(expert.multiDeck > 16, report)
        #expect(easy.total > 80, report)
    }
}
