//
//  BattleFieldView-ViewModel.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 19/07/2024.
//
//  Phase 0: reduced to a thin, view-facing facade. Board logic lives in
//  `GameEngine`; the opponent's targeting lives behind the `Opponent` protocol
//  (currently `ComputerOpponent`). The public API used by the views —
//  configure / checkShipOnFire / computerTurn / chooseSound — is unchanged.
//

import Foundation
import Observation

@MainActor
@Observable
class GameLogicViewModel {

    @ObservationIgnored var appState: AppState!
    @ObservationIgnored var player: PlayerData!
    @ObservationIgnored var enemy: PlayerData!
    @ObservationIgnored private(set) var isConfigured = false

    @ObservationIgnored private let engine = GameEngine()
    @ObservationIgnored private var opponent: Opponent!

    init() {}

    /// Injects the shared game objects once the owning view is on screen.
    func configure(appState: AppState, enemy: PlayerData, player: PlayerData) {
        self.appState = appState
        self.enemy = enemy
        self.player = player
        engine.configure(appState: appState, player: player, enemy: enemy)
        opponent = ComputerOpponent(appState: appState, ownFleet: enemy, targetBoard: player)
        self.isConfigured = true
    }

    /// Applies the human player's shot at the target board (delegates to the engine).
    func checkShipOnFire(row: Int, column: Int, target: PlayerData) {
        engine.checkShipOnFire(row: row, column: column, target: target)
        autosave()
    }

    /// Persists the game, but only at stable points — when it's the human's turn
    /// and the match is on. Resuming therefore always lands on "player to shoot",
    /// so there is never an in-flight computer sequence to restart.
    private func autosave() {
        guard appState.gameIsActive, !appState.enemysTurn else { return }
        GameStore.save(GameSnapshot(appState: appState, player: player, enemy: enemy))
    }

    /// Runs the opponent's (computer's) turn: keep firing while it keeps hitting
    /// and the game is still on.
    func computerTurn() {
        Task { @MainActor in
            await performShot()
        }
    }

    private func performShot() async {
        let shot = await opponent.nextShot()
        let row = shot.row
        let column = shot.column

        player.fireStrokeArray[row - 1][column - 1] = true
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            player.fireStrokeArray[row - 1][column - 1] = false
        }

        engine.checkShipOnFire(row: row, column: column, target: player)

        // Keep firing while the computer keeps hitting and the game is still on.
        if player.cells[row - 1][column - 1].cellStatus != .missed && appState.gameIsActive {
            try? await Task.sleep(for: .seconds(1))
            await performShot()
        } else {
            // Computer's turn is over: control returns to the player — a stable
            // point to persist the game.
            autosave()
        }
    }

    // MARK: - Hints (Phase 6)

    /// The cost of a hint at the current difficulty (== the win reward).
    var hintCost: Int { appState.difficultyLevel.pointsValue }

    /// True when a hint can be requested right now.
    var canUseHint: Bool {
        appState.gameIsActive && !appState.enemysTurn && ProgressStore.shared.points >= hintCost
    }

    /// Spends points to reveal a random enemy cell that definitely holds an
    /// undestroyed ship (and hasn't been fired at or revealed yet).
    /// RETURNS: whether a hint was revealed.
    @discardableResult
    func requestHint() -> Bool {
        guard canUseHint else { return false }
        let candidates = enemy.ships
            .filter { !$0.isDestroyed }
            .flatMap { $0.coordinates }
            .filter { coordinate in
                enemy.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus == .unknown
                    && !appState.revealedHintCells.contains(where: { $0 == coordinate })
            }
        guard let pick = candidates.randomElement(), ProgressStore.shared.spend(hintCost) else { return false }
        appState.revealedHintCells.append(pick)
        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
        return true
    }

    /// Chooses what sound to play depending on the cell status.
    func chooseSound(row: Int, column: Int) {
        switch enemy.cells[row][column].cellStatus {
        case .missed:
            return
        case .onFire:
            AppState.playSound(sound: "blast_onfire2.wav")
        case .destroyed:
            AppState.playSound(sound: "Glass_Break-stephan_schutze-958181291.wav")
        default:
            AppState.playSound(sound: "click_sound.wav")
        }
    }
}
