//
//  LadderWinRateTests.swift
//  SeaBattleTests
//
//  Shots to clear a board only measures half a level: since the expert also
//  hides its own fleet now and then, the honest measure of difficulty is how
//  often the computer WINS — attack and defence together, with turns
//  alternating and a hit keeping the turn.
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
    ///
    /// `hiddenShare` overrides how often the computer hides, for calibration;
    /// `nil` is the level's own share.
    private func computerWins(at level: AppState.DifficultyLevel,
                              hiddenShare: Double? = nil) async -> Bool {
        let computerBoard = PlayerData(side: .foe)
        if let share = hiddenShare {
            computerBoard.place(Double.random(in: 0..<1) < share
                                ? FleetLayout.hiddenArrangement()
                                : FleetLayout.random())
        } else {
            // Через ту же функцию, которой пользуется приложение. Раньше тест
            // расставлял скрытый флот сам, и из-за этого восемь месяцев не было
            // видно, что в живой партии сокрытие вообще не применяется.
            ComputerOpponent.arrangeFleet(for: level, on: computerBoard)
        }
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
                         hiddenShare: Double? = nil,
                         matches: Int) async -> Int {
        var wins = 0
        for _ in 0..<matches {
            if await computerWins(at: level, hiddenShare: hiddenShare) { wins += 1 }
        }
        return wins * 100 / matches
    }

    @Test("Only the expert hides its fleet, and only now and then")
    func onlyTheExpertHides() {
        // The structural half of the ladder, with no statistics in it. Hiding
        // in every match is readable — a player who expects it fires along the
        // edges first and wins more, not less — so the share has to stay well
        // below one half (see `hiddenFleetShare` for the measured peak).
        #expect(AppState.DifficultyLevel.easy.hiddenFleetShare == 0)
        #expect(AppState.DifficultyLevel.medium.hiddenFleetShare == 0)
        #expect(AppState.DifficultyLevel.hard.hiddenFleetShare == 0)

        let expert = AppState.DifficultyLevel.expert.hiddenFleetShare
        #expect(expert > 0.1 && expert < 0.25)
    }

    @Test("The four levels win in order")
    func theLadderIsMonotone() async {
        // 300, not 100: the upper steps are only a few points, and at 100 a
        // run on 09.10 drew hard 34% against medium 48% from pure noise.
        let matches = 300
        var rates: [AppState.DifficultyLevel: Int] = [:]
        for (level, _) in Self.settings {
            rates[level] = await winRate(at: level, matches: matches)
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

        // Measured outside the app at roughly 1 · 39 · 43 · 52 per cent (09.10,
        // after hard stopped hiding and the expert started hiding only now and
        // then). Only the bottom step is large enough to assert with room to
        // spare.
        #expect(rates[.medium]! > rates[.easy]! + 15, report)

        // The upper steps are four to nine points — a shot or so each, which
        // is all the targeting above medium is worth — and the standard error
        // of a difference here is about four. Asserting a margin would make the
        // test flaky; what must not happen is a clear inversion. The order
        // itself is pinned down in shots by `DifficultyLadderTests` and
        // structurally by `onlyTheExpertHides`.
        #expect(rates[.hard]! > rates[.medium]! - 8, report)
        #expect(rates[.expert]! > rates[.hard]! - 8, report)

        // Easy has to be a giveaway, and expert has to be beatable — the 10
        // points for winning and the hints priced against it depend on it.
        #expect(rates[.easy]! < 15, report)
        #expect(rates[.expert]! < 80, report)
    }

    @Test("Calibration: win rate by share of hidden matches, expert",
          .disabled("A calibration run, not a check. Enable it when retuning the dials."))
    func calibrateHiding() async {
        // Against a reference opponent that does not expect the hiding, so the
        // rate only grows with the share. What caps the share is the opponent
        // who does expect it; that was measured outside the app.
        let matches = 100
        var lines = ["Expert win rate by share of matches with a hidden fleet:"]
        for share in [0, 0.16, 0.3, 1] {
            let rate = await winRate(at: .expert, hiddenShare: share, matches: matches)
            lines.append("  \(Int(share * 100))% hidden -> \(rate)%")
        }
        print(lines.joined(separator: "\n"))
    }
}
