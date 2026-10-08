//
//  ExpertPlacementTests.swift
//  SeaBattleTests
//
//  The expert level does not only shoot well, it also hides its fleet — in a
//  random share of matches. A hidden fleet gives away less water: sinking a
//  ship tells the other player that everything touching it is water, and that
//  gift shrinks when a ship sits against an edge (part of its ring is off the
//  board) or one cell from another ship (they share the cells between them).
//
//  Three things have to hold: the hidden layout must really be less exposed,
//  being less exposed must really cost the attacker shots, and it must NOT be
//  readable. The last one is the one that went wrong before 09.10 — the old
//  hill climb put the four-decker on an edge in 87% of matches, and a player
//  who fired there first beat the expert 72% of the time.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct ExpertPlacementTests {

    /// A fleet arranged the way the expert arranges its own when it hides.
    private func hiddenFleet() -> [ShipPlacement] {
        FleetLayout.hiddenArrangement()
    }

    // MARK: - The layout itself

    @Test("A hidden layout is still a legal standard fleet", arguments: 0..<20)
    func layoutIsLegal(_ iteration: Int) {
        let layout = hiddenFleet()
        let lengths = layout.map(\.length).sorted(by: >)

        #expect(FleetLayout.isValid(layout))
        #expect(layout.count == FleetLayout.shipCount)
        #expect(lengths == FleetLayout.deckCounts)
        #expect(layout.allSatisfy { $0.isOnBoard })
        // Longest-first, the order `PlayerData.place` numbers ships in.
        #expect(layout.map(\.length) == FleetLayout.deckCounts)
        #expect(Set(layout.map(\.id)).count == FleetLayout.shipCount)
    }

    @Test("It gives away clearly less water than a random layout")
    func exposureIsLower() {
        let samples = 100
        let random = (0..<samples).map { _ in FleetLayout.ringExposure(of: FleetLayout.random()) }
        let hidden = (0..<samples).map { _ in FleetLayout.ringExposure(of: hiddenFleet()) }

        let randomAverage = Double(random.reduce(0, +)) / Double(samples)
        let hiddenAverage = Double(hidden.reduce(0, +)) / Double(samples)
        print(String(format: "Ring exposure: random %.1f cells, hidden %.1f cells",
                     randomAverage, hiddenAverage))

        // Measured at 62 and 55. A weighting, not a target, so single layouts
        // vary on both sides of the average — that variety is the point.
        #expect(hiddenAverage < randomAverage - 4)
        #expect(hiddenAverage > 50, "Hiding this hard packs the fleet into the edges again")
    }

    @Test("Strength 0 is a plain random layout")
    func zeroStrengthIsRandom() {
        let samples = 100
        let exposure = (0..<samples).map { _ in
            FleetLayout.ringExposure(of: FleetLayout.hiddenArrangement(strength: 0))
        }
        let average = Double(exposure.reduce(0, +)) / Double(samples)
        #expect(abs(average - Double(FleetLayout.randomExposure)) < 2.5)
    }

    @Test("Hiding does not give the big ships away")
    func layoutsAreNotReadable() {
        // What the old hill climb got wrong: the least exposed spot for a long
        // ship is almost always on an edge or in a corner, so a player who
        // fired there first found it at once. Measured, per four-decker:
        //
        //                     on an edge   in a corner
        //     random              55%          11%
        //     hidden now          72%          22%
        //     old hill climb      87%          42%
        let samples = 300
        let corners: Set<Coordinate> = [
            Coordinate(row: 1, column: 1), Coordinate(row: 1, column: Board.size),
            Coordinate(row: Board.size, column: 1), Coordinate(row: Board.size, column: Board.size)
        ]
        var onEdge = 0
        var inCorner = 0
        var positions = Set<String>()
        for _ in 0..<samples {
            let fourDecker = hiddenFleet().first { $0.length == 4 }!
            let cells = fourDecker.cells
            if cells.contains(where: { [1, Board.size].contains($0.row) || [1, Board.size].contains($0.column) }) {
                onEdge += 1
            }
            if cells.contains(where: corners.contains) { inCorner += 1 }
            positions.insert("\(fourDecker.origin)-\(fourDecker.orientation)")
        }
        let text = "Four-decker on an edge \(onEdge * 100 / samples)%, in a corner \(inCorner * 100 / samples)%, \(positions.count) distinct positions"
        print(text)
        #expect(onEdge * 100 < samples * 80, Comment(rawValue: text))
        #expect(inCorner * 100 < samples * 32, Comment(rawValue: text))
        #expect(positions.count > 60, Comment(rawValue: text))
    }

    @Test("Only the expert hides, in about one match in six")
    func hidingShare() {
        var generator = SystemRandomNumberGenerator()
        for level in [AppState.DifficultyLevel.easy, .medium, .hard] {
            #expect(level.hiddenFleetShare == 0)
            #expect((0..<200).allSatisfy { _ in
                !ComputerOpponent.fleet(for: level, using: &generator).isHidden
            })
        }

        let matches = 3000
        let hidden = (0..<matches).count { _ in
            ComputerOpponent.fleet(for: .expert, using: &generator).isHidden
        }
        // 16% of 3000 is 480, with a standard deviation of 20.
        #expect((400...560).contains(hidden), "Hid in \(hidden) of \(matches) matches")
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

        // Measured at about +6 against an attacker that does not expect it —
        // the reason a hidden match is worth having at all. Against one that
        // does, a hidden fleet is no harder than a random one, which is why the
        // expert hides only now and then (`hiddenFleetShare`).
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

    @Test("Calibration: what each strength of hiding is worth",
          .disabled("A calibration run, not a check. Enable it when retuning the dial."))
    func calibrateTheDial() async {
        // Against an attacker that does NOT expect the hiding — the share in
        // `hiddenFleetShare` is what protects against one that does, and that
        // was measured outside the app (see the comment there).
        let matches = 60
        var lines: [String] = ["Expert win rate by hiding strength, every match hidden:"]
        for strength in [0, 0.15, FleetLayout.hidingStrength, 0.5] {
            var wins = 0
            var exposure = 0
            for _ in 0..<matches {
                let fleet = FleetLayout.hiddenArrangement(strength: strength)
                exposure += FleetLayout.ringExposure(of: fleet)
                if await computerWinsMatch(computerFleet: fleet,
                                           playerFleet: FleetLayout.random()) {
                    wins += 1
                }
            }
            lines.append(String(format: "  strength %.2f -> %5.1f cells, wins %3d%%",
                                strength, Double(exposure) / Double(matches),
                                wins * 100 / matches))
        }
        print(lines.joined(separator: "\n"))
    }
}
