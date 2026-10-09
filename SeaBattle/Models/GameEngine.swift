//
//  GameEngine.swift
//  SeaBattle
//
//  The vs-computer match driver. Since R0.4 it decides nothing about the rules
//  itself: a shot is projected onto a `Board`, `Board.apply(shotAt:)` resolves
//  it, and the result is written back. What is left here is everything the core
//  deliberately does not know about — sound, the saved game, statistics and the
//  end-of-match alert.
//
//  Before R0.4 this file also carried `checkShipIsTotallyDestroyed` and the
//  ~100-line `definePriorityTargetCells`, which duplicated rules that
//  `HotSeatGame` and `NetworkGame` each implemented differently (audit A1), and
//  which read the player's board no matter whose board had been shot at (B4).
//  The "finish the damaged ship" targeting it fed now lives in the opponent,
//  derived from the board instead of cached in `AppState`.
//

import Foundation

@MainActor
final class GameEngine {

    private(set) var appState: AppState!
    private(set) var player: PlayerData!
    private(set) var enemy: PlayerData!

    /// Injects the shared game objects once the owning view is on screen.
    func configure(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.appState = appState
        self.player = player
        self.enemy = enemy
    }

    /// Applies a shot to `target` and handles everything around the rules:
    /// sound, the end of the match, statistics and whose turn it is.
    @discardableResult
    func checkShipOnFire(row: Int, column: Int, target: PlayerData) -> Board.ShotResult {
        var board = target.coreBoard
        let result = board.apply(shotAt: Coordinate(row: row, column: column))

        if case .sunk(let ship) = result, target.side == .foe, appState.autoRevealAroundSunk {
            // Optional beginner protection on the opponent's board: reveal the
            // ring that cannot hold a ship. Firing there stays legal.
            board.revealRing(around: ship)
        }
        target.apply(board)

        play(result, on: target)
        if board.isFleetDestroyed {
            finish(loser: target)
        }

        // `target` is the board that was fired AT. A miss (or a repeat shot)
        // hands the turn to whoever owns that board; a hit keeps it with the
        // shooter. Until R2.3 the flag ignored the result and a hit on the
        // computer's board passed the turn anyway — the pre-R0.4 code had kept
        // it by returning early, and the port lost that.
        let shooterIsComputer = target.side == .you
        appState.enemysTurn = result.keepsTurn ? shooterIsComputer : !shooterIsComputer
        return result
    }

    // MARK: - Presentation around the rules

    /// Only incoming fire is voiced here — the player hears their own hull take
    /// damage. The cue for damage they deal is chosen by the view model, which
    /// knows whether the shot came from a tap.
    private func play(_ result: Board.ShotResult, on target: PlayerData) {
        guard target.side == .you else { return }
        HapticService.shared.play(shot: result, incoming: true)
        guard appState.soundOn else { return }
        switch result {
        case .miss:
            AudioService.shared.play(.missed)
        case .hit:
            AudioService.shared.play(.hit)
        case .sunk:
            AudioService.shared.play(.sunk)
        case .repeated, .offBoard:
            break
        }
    }

    private func finish(loser: PlayerData) {
        appState.gameIsActive = false
        appState.gameIsOver = true
        AppState.stopMusic()
        // The match is over — drop the saved game.
        GameStore.clear()
        // The side whose whole fleet is sunk is the loser.
        if loser.side == .foe {
            ProgressStore.shared.recordWin(.computer(appState.difficultyLevel))
        } else {
            ProgressStore.shared.recordLoss(.computer(appState.difficultyLevel))
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            loser.showFinishGameAlert = true
        }
    }
}
