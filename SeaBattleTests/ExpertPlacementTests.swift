//
//  ExpertPlacementTests.swift
//  SeaBattleTests
//
//  The expert level does not only shoot well, it also HIDES well: it arranges
//  its own fleet to give away as little water as possible. Sinking a ship tells
//  the other player that everything touching it is water, and that gift shrinks
//  when a ship sits against an edge (part of its ring is off the board) or one
//  cell from another ship (they share the cells between them).
//
//  Two things have to hold, and the second is the one that matters: the layout
//  must really be less exposed, and being less exposed must really cost the
//  attacker shots. It also must not become predictable — a fleet that hides in
//  the same corner every game is worse than a random one.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct ExpertPlacementTests {

    /// A fleet arranged the way the expert level arranges its own.
    private func hiddenFleet() -> [ShipPlacement] {
        FleetLayout.arrangement(givingAwayAtMost: expertTarget)
    }

    private var expertTarget: Int { AppState.DifficultyLevel.expert.fleetExposureTarget! }

    // MARK: - The layout itself

    @Test("A hidden layout is still a legal standard fleet", arguments: 0..<20)
    func layoutIsLegal(_ iteration: Int) {
        let layout = hiddenFleet()
        let lengths = layout.map(\.length).sorted(by: >)

        #expect(FleetLayout.isValid(layout))
        #expect(layout.count == FleetLayout.shipCount)
        #expect(lengths == FleetLayout.deckCounts)
        #expect(layout.allSatisfy { $0.isOnBoard })
    }

    @Test("It gives away much less water than a random layout")
    func exposureIsLower() {
        let samples = 60
        let random = (0..<samples).map { _ in FleetLayout.ringExposure(of: FleetLayout.random()) }
        let hidden = (0..<samples).map { _ in FleetLayout.ringExposure(of: hiddenFleet()) }

        let randomAverage = Double(random.reduce(0, +)) / Double(samples)
        let hiddenAverage = Double(hidden.reduce(0, +)) / Double(samples)
        print(String(format: "Ring exposure: random %.1f cells, hidden %.1f cells",
                     randomAverage, hiddenAverage))

        #expect(hiddenAverage < randomAverage - 5)
        // Every hidden layout should beat the average random one, not just the
        // average of them.
        #expect(hidden.max()! < Int(randomAverage))
    }

    @Test("Hiding does not settle into one corner")
    func layoutsStayVaried() {
        // Twenty layouts, looking at where the four-decker ends up. A fleet
        // that always packs the same way would be learned in two matches, so
        // variety is a requirement, not a nice-to-have.
        let fourDeckers = (0..<20).map { _ in
            hiddenFleet().first { $0.length == 4 }!
        }
        let distinctPositions = Set(fourDeckers.map { "\($0.origin)-\($0.orientation)" })
        #expect(distinctPositions.count >= 5,
                "The four-decker only ever landed in \(distinctPositions.count) positions")

        // And it should not always be the same edge of the board either.
        let rows = Set(fourDeckers.map(\.origin.row))
        let columns = Set(fourDeckers.map(\.origin.column))
        #expect(rows.count + columns.count >= 6)
    }

    // MARK: - Does hiding actually cost the attacker anything?

    /// Plays the strongest attacker the app has against `fleet` and RETURNS how
    /// many shots it needed to clear it.
    private func shotsToClear(_ fleet: [ShipPlacement]) async -> Int {
        let appState = AppState()
        appState.difficulty = 3   // expert; see DifficultyLadderTests for the mapping
        #expect(appState.difficultyLevel == .expert)

        let target = PlayerData(side: .you)
        target.place(fleet)
        let attacker = ComputerOpponent(appState: appState,
                                        ownFleet: PlayerData(side: .foe),
                                        targetBoard: target)
        for shot in 1...Board.cellCount {
            let coordinate = await attacker.nextShot()
            var board = target.coreBoard
            board.apply(shotAt: coordinate)
            target.apply(board)
            if board.isFleetDestroyed { return shot }
        }
        Issue.record("The attacker failed to clear a fleet in \(Board.cellCount) shots")
        return Board.cellCount
    }

    private func averageShotsToClear(_ layouts: [[ShipPlacement]]) async -> Double {
        var total = 0
        for layout in layouts {
            total += await shotsToClear(layout)
        }
        return Double(total) / Double(layouts.count)
    }

    @Test("A hidden fleet takes the best attacker longer to clear")
    func hidingCostsTheAttackerShots() async {
        let matches = 150
        let randomFleets = (0..<matches).map { _ in FleetLayout.random() }
        let hiddenFleets = (0..<matches).map { _ in hiddenFleet() }

        let againstRandom = await averageShotsToClear(randomFleets)
        let againstHidden = await averageShotsToClear(hiddenFleets)
        let text = String(format: """
            Expert attacker against %d fleets of each kind.
            Average shots to clear: random layout %.2f, hidden layout %.2f (+%.2f)
            """, matches, againstRandom, againstHidden, againstHidden - againstRandom)
        print(text)

        // The whole point of arranging the fleet this way, and by far the
        // largest single effect in the AI: even at the deliberately mild
        // setting the level uses, it is worth more than every targeting
        // improvement in the ladder put together.
        #expect(againstHidden > againstRandom + 3, Comment(rawValue: text))
    }

    // MARK: - What it does to a real match

    /// Plays a whole alternating-turn match: the player shoots first, a hit
    /// keeps the turn. RETURNS true if the computer won.
    private func computerWinsMatch(computerFleet: [ShipPlacement],
                                   playerFleet: [ShipPlacement]) async -> Bool {
        let appState = AppState()
        appState.difficulty = 3
        let computerBoard = PlayerData(side: .foe)
        let playerBoard = PlayerData(side: .you)
        computerBoard.place(computerFleet)
        playerBoard.place(playerFleet)

        // Both sides shoot as well as the app can, so the only thing being
        // compared is how well the two fleets are hidden.
        let computer = ComputerOpponent(appState: appState,
                                        ownFleet: computerBoard,
                                        targetBoard: playerBoard)
        let player = ComputerOpponent(appState: appState,
                                       ownFleet: playerBoard,
                                       targetBoard: computerBoard)

        var computerToShoot = false        // the player opens, as in the app
        for _ in 0..<(2 * Board.cellCount) {
            let shooter = computerToShoot ? computer : player
            let targetBoard = computerToShoot ? playerBoard : computerBoard
            let shot = await shooter.nextShot()

            var board = targetBoard.coreBoard
            let result = board.apply(shotAt: shot)
            targetBoard.apply(board)
            if board.isFleetDestroyed { return computerToShoot }
            if !result.keepsTurn { computerToShoot.toggle() }
        }
        Issue.record("A match between two expert players never finished")
        return false
    }

    @Test("Calibration: what each setting of the hiding dial is worth",
          .disabled("A calibration run, not a check. Enable it when retuning the dial."))
    func calibrateTheDial() async {
        let matches = 60
        var lines: [String] = ["Expert win rate by how much water its fleet gives away:"]
        for target in [FleetLayout.randomExposure, 58, 54, 50, 46, 42, 34] {
            var wins = 0
            var exposure = 0
            for _ in 0..<matches {
                let fleet = FleetLayout.arrangement(givingAwayAtMost: target)
                exposure += FleetLayout.ringExposure(of: fleet)
                if await computerWinsMatch(computerFleet: fleet,
                                           playerFleet: FleetLayout.random()) {
                    wins += 1
                }
            }
            lines.append(String(format: "  target %3d -> actual %5.1f cells, wins %3d%%",
                                target, Double(exposure) / Double(matches),
                                wins * 100 / matches))
        }
        print(lines.joined(separator: "\n"))
    }

    @Test("Hiding its fleet is what wins the expert its matches")
    func hidingDecidesMatches() async {
        let matches = 100
        var winsWithHiding = 0
        var winsWithRandom = 0
        for _ in 0..<matches {
            // Same conditions both times, changing only how the computer's own
            // fleet was arranged. The player always gets a random layout,
            // which is what the app's auto-arrange produces.
            if await computerWinsMatch(computerFleet: hiddenFleet(),
                                       playerFleet: FleetLayout.random()) {
                winsWithHiding += 1
            }
            if await computerWinsMatch(computerFleet: FleetLayout.random(),
                                       playerFleet: FleetLayout.random()) {
                winsWithRandom += 1
            }
        }
        let text = """
            Expert win rate over \(matches) matches, both sides shooting as expert,
            player opens: hiding its own fleet \(winsWithHiding)%, random layout \(winsWithRandom)%
            """
        print(text)

        // Wide margin on purpose: this is the step from "wins about half its
        // matches" to "the hardest thing in the app", and it is the only
        // reason the expert is meaningfully harder than hard, whose shooting
        // is a shot or two behind it (see `DifficultyLadderTests`).
        #expect(winsWithHiding > winsWithRandom + 10, Comment(rawValue: text))
        // And it must still lose sometimes, or the 10 points for beating it
        // and the hints priced against it are unreachable.
        #expect(winsWithHiding < 95, Comment(rawValue: text))
    }
}
