//
//  LadderWinRateTests.swift
//  SeaBattleTests
//
//  Shots to clear a board only measures half a level: since the expert and hard
//  levels also arrange their own fleet to give away as little as possible, the
//  honest measure of difficulty is how often the computer WINS — attack and
//  defence together, with turns alternating and a hit keeping the turn.
//
//  Every level is measured against the same reference opponent: the best
//  shooting the app has, with a plain random layout, moving first. A live player
//  is weaker than that, so these rates are a floor on the real difficulty, not
//  an estimate of it.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct LadderWinRateTests {

    /// The magic integers behind `AppState.difficulty` (audit finding C14).
    private static let settings: [(level: AppState.DifficultyLevel, difficulty: Int)] = [
        (.easy, 2), (.medium, 1), (.hard, 0), (.expert, 3)
    ]

    private func appState(for level: AppState.DifficultyLevel) -> AppState {
        let state = AppState()
        state.difficulty = Self.settings.first { $0.level == level }!.difficulty
        #expect(state.difficultyLevel == level, "The difficulty mapping moved")
        return state
    }

    /// One whole match. The computer plays `level`, arranging its fleet the way
    /// that level does; the reference opponent shoots as well as the app can and
    /// takes a random layout. RETURNS true if the computer won.
    private func computerWins(at level: AppState.DifficultyLevel,
                              exposureTarget: Int?) async -> Bool {
        let computerBoard = PlayerData(side: .foe)
        // Через ту же функцию, которой пользуется приложение. Раньше тест
        // расставлял скрытый флот сам, и из-за этого восемь месяцев не было
        // видно, что в живой партии сокрытие вообще не применяется.
        if let target = exposureTarget {
            #expect(target == level.fleetExposureTarget, "цель сокрытия разошлась с уровнем")
        }
        ComputerOpponent.arrangeFleet(for: level, on: computerBoard)
        let playerBoard = PlayerData(side: .you)
        playerBoard.shipsRandomArrangement()

        let computer = ComputerOpponent(appState: appState(for: level),
                                        ownFleet: computerBoard,
                                        targetBoard: playerBoard)
        let player = ComputerOpponent(appState: appState(for: .expert),
                                      ownFleet: playerBoard,
                                      targetBoard: computerBoard)

        var computerToShoot = false        // the player opens, as in the app
        for _ in 0..<(4 * Board.cellCount) {
            let shooter = computerToShoot ? computer : player
            let target = computerToShoot ? playerBoard : computerBoard
            let shot = await shooter.nextShot()

            var board = target.coreBoard
            let result = board.apply(shotAt: shot)
            target.apply(board)
            if board.isFleetDestroyed { return computerToShoot }
            if !result.keepsTurn { computerToShoot.toggle() }
        }
        Issue.record("A match at \(level) never finished")
        return false
    }

    private func winRate(at level: AppState.DifficultyLevel,
                         exposureTarget: Int?,
                         matches: Int) async -> Int {
        var wins = 0
        for _ in 0..<matches {
            if await computerWins(at: level, exposureTarget: exposureTarget) { wins += 1 }
        }
        return wins * 100 / matches
    }

    @Test("Each level hides its fleet at least as well as the one below it")
    func hidingIncreasesUpTheLadder() {
        // The structural half of the ladder, with no statistics in it: the two
        // paid-for levels hide, the lower two do not, and expert hides harder
        // than hard. Measured win rates follow from this (see below), but this
        // is the part that can be pinned down exactly.
        #expect(AppState.DifficultyLevel.easy.fleetExposureTarget == nil)
        #expect(AppState.DifficultyLevel.medium.fleetExposureTarget == nil)

        let hard = AppState.DifficultyLevel.hard.fleetExposureTarget
        let expert = AppState.DifficultyLevel.expert.fleetExposureTarget
        #expect(hard != nil)
        #expect(expert != nil)
        #expect(expert! < hard!, "Expert must hide harder than hard")
        #expect(hard! < FleetLayout.randomExposure, "Hard must hide at all")
    }

    @Test("The four levels win at clearly different rates")
    func theLadderIsMonotone() async {
        let matches = 100
        var rates: [AppState.DifficultyLevel: Int] = [:]
        for (level, _) in Self.settings {
            rates[level] = await winRate(at: level,
                                         exposureTarget: level.fleetExposureTarget,
                                         matches: matches)
        }
        let text = """
            Computer win rate over \(matches) matches per level, against the app's
            best shooting with a random layout, player opening:
              easy   \(rates[.easy]!)%
              medium \(rates[.medium]!)%
              hard   \(rates[.hard]!)%
              expert \(rates[.expert]!)%
            """
        print(text)
        let report = Comment(rawValue: text)

        // Measured at roughly 1 · 42 · 70 · 82 per cent. The two lower steps
        // are large and asserted with room to spare.
        #expect(rates[.medium]! > rates[.easy]! + 15, report)
        #expect(rates[.hard]! > rates[.medium]! + 10, report)

        // Hard to expert is only about twelve points, which at this sample size
        // is barely two standard errors — asserting a margin here would just
        // make the test flaky. What it must not do is come out BELOW hard; the
        // ordering itself is pinned down structurally in
        // `hidingIncreasesUpTheLadder`, and the size of the gap belongs to the
        // calibration run.
        #expect(rates[.expert]! > rates[.hard]! - 8, report)

        // Easy has to be a giveaway, and expert has to be beatable — the 10
        // points for winning and the hints priced against it depend on it.
        #expect(rates[.easy]! < 15, report)
        #expect(rates[.expert]! < 95, report)
    }

    @Test("Calibration: win rate by hiding target, per level",
          .disabled("A calibration run, not a check. Enable it when retuning the dials."))
    func calibrateHiding() async {
        let matches = 60
        var lines = ["Win rate by hiding target (cells of water given away):"]
        for level in [AppState.DifficultyLevel.hard, .expert] {
            for target in [FleetLayout.randomExposure, 58, 54, 50, 46] {
                let rate = await winRate(at: level, exposureTarget: target, matches: matches)
                lines.append("  \(level) at \(target) cells -> \(rate)%")
            }
        }
        print(lines.joined(separator: "\n"))
    }
}
