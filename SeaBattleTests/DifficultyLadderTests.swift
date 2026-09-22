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

    private var harderLevels: [AppState.DifficultyLevel] { [.medium, .hard, .expert] }

    // MARK: - What each level does with damage

    @Test("Every level above easy follows up on a damaged ship")
    func harderLevelsFinishWhatTheyStarted() {
        // One hit on the four-decker at (1,1)-(1,4); it is still afloat.
        let board = maskedBoard(afterShotsAt: [Coordinate(row: 1, column: 2)])
        let neighbours = Set(Coordinate(row: 1, column: 2).orthogonalNeighbours)

        for level in harderLevels {
            let candidates = opponent(at: level).targetCandidates(on: board)
            #expect(!candidates.isEmpty)
            #expect(candidates.allSatisfy { neighbours.contains($0) },
                    "\(level) considered \(candidates) instead of probing the hit")
        }
    }

    @Test("Easy walks away from a ship it has already hit")
    func easyDoesNotFollowUp() {
        let board = maskedBoard(afterShotsAt: [Coordinate(row: 1, column: 2)])
        let candidates = opponent(at: .easy).targetCandidates(on: board)

        // Everything that has not been fired at, damage or no damage.
        #expect(candidates.count == Board.cellCount - 1)
        #expect(candidates.contains(Coordinate(row: 10, column: 10)))
    }

    @Test("Two hits in a row fix the orientation, so only the ends are tried")
    func linesAreExtendedNotProbedSideways() {
        let board = maskedBoard(afterShotsAt: [Coordinate(row: 1, column: 2),
                                               Coordinate(row: 1, column: 3)])
        let ends: Set<Coordinate> = [Coordinate(row: 1, column: 1), Coordinate(row: 1, column: 4)]

        for level in harderLevels {
            let candidates = Set(opponent(at: level).targetCandidates(on: board))
            #expect(candidates == ends,
                    "\(level) fired sideways off a known line: \(candidates)")
        }
    }

    // MARK: - What each level does with a sunk ship

    @Test("Above easy, the ring around a sunk ship is ruled out")
    func harderLevelsSkipTheRing() {
        // Sink the single-deck ship at (5,4) outright.
        let victim = Coordinate(row: 5, column: 4)
        let board = maskedBoard(afterShotsAt: [victim])
        #expect(board[victim] == .sunk)
        let ring = Set(victim.neighbours)

        for level in harderLevels {
            let candidates = Set(opponent(at: level).targetCandidates(on: board))
            #expect(candidates.isDisjoint(with: ring),
                    "\(level) still considers cells that cannot hold a ship")
        }
        // Easy keeps wasting shots there, which is the point of easy.
        let easy = Set(opponent(at: .easy).targetCandidates(on: board))
        #expect(!easy.isDisjoint(with: ring))
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
        let report: Comment = """
            shots to sink the six multi-deck ships (and to clear the board):
            easy \(easy.multiDeck) (\(easy.total)), medium \(medium.multiDeck) (\(medium.total)), \
            hard \(hard.multiDeck) (\(hard.total)), expert \(expert.multiDeck) (\(expert.total))
            """

        // Paired over 100 random fleets. Any two levels coming out equal here
        // would be the flat ladder of finding A6 all over again. R0.6 measured
        // roughly 95 · 53 · 46 · 45 shots; the margins below leave room for
        // the run-to-run spread but not for a rung collapsing into its
        // neighbour.
        #expect(medium.multiDeck < easy.multiDeck - 20, report)
        #expect(hard.multiDeck < medium.multiDeck - 3, report)
        #expect(expert.multiDeck < hard.multiDeck - 0.5, report)

        // Clearing the whole board stays within a couple of shots across the
        // three thinking levels, and that is expected: see `shotsNeeded`.
        #expect(expert.total < medium.total, report)

        // Sanity: 16 cells belong to multi-deck ships, so nothing can sink them
        // in fewer than 16 shots, and easy is a random sweep of 100 cells.
        #expect(expert.multiDeck > 16, report)
        #expect(easy.total > 80, report)
    }
}
