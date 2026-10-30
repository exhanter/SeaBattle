//
//  GameSnapshot.swift
//  SeaBattle
//
//  Phase 0: a flat, Codable snapshot of a match against the computer — the
//  single-slot local save (`GameStore`). Since 30.10 each side is stored as the
//  rules core's own `Board`; the legacy `PlayerSnapshot` (cells, ships and the
//  fire-stroke overlay of the pre-redesign `PlayerData`) is gone with it.
//

import Foundation

/// A serializable snapshot of an entire match.
struct GameSnapshot: Codable, Sendable {

    /// Bumped whenever the stored shape changes. `GameStore` refuses to load a
    /// snapshot written by a different version — the field was written but
    /// never checked before R0.4 (audit finding B12), so a format change would
    /// have decoded into nonsense or silently vanished.
    ///
    /// Version 2 (R0.4) dropped `potentialCellsForFinishingDamagedShip`: the
    /// computer's "finish the damaged ship" targeting is now derived from the
    /// board, so there is no cache to carry across a relaunch.
    /// Version 3 (30.10) stores each side as a `Board` instead of the legacy
    /// cells and ships; a v2 save is discarded, not converted (nothing had been
    /// released, the only saves were the developer's own).
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var difficulty: Int
    var enemysTurn: Bool
    var gameIsActive: Bool
    var manualShipArrangement: Bool
    var player: Board
    var enemy: Board
    /// R2.5: выстрелы, серия и подсказки игрока для экрана итогов. Поле
    /// необязательное: сохранение без него читается с `nil` (счёт начнётся с
    /// нуля).
    var tally: MatchTally?

    @MainActor
    init(appState: AppState, player: BattleSide, enemy: BattleSide,
         tally: MatchTally? = nil) {
        self.schemaVersion = Self.currentSchemaVersion
        self.difficulty = appState.difficulty
        self.enemysTurn = appState.enemysTurn
        self.gameIsActive = appState.gameIsActive
        self.manualShipArrangement = appState.manualShipArrangement
        self.player = player.board
        self.enemy = enemy.board
        self.tally = tally
    }

    /// Applies this snapshot back onto the live game objects.
    @MainActor
    func apply(to appState: AppState, player: BattleSide, enemy: BattleSide) {
        appState.difficulty = difficulty
        appState.enemysTurn = enemysTurn
        appState.gameIsActive = gameIsActive
        appState.manualShipArrangement = manualShipArrangement
        player.board = self.player
        enemy.board = self.enemy
    }
}
