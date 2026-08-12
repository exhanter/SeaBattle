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
        }
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
