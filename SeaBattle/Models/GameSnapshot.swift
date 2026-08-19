//
//  GameSnapshot.swift
//  SeaBattle
//
//  Phase 0: a flat, Codable snapshot of a full match. This single format backs
//  local game saving (Phase 1) and the wire format for hot-seat / network play
//  (Phases 5/5a). Conversions to and from the live @Observable objects live
//  here so the rest of the app keeps working with the existing models.
//

import Foundation

/// A serializable snapshot of one side's board.
struct PlayerSnapshot: Codable, Sendable {
    var name: String
    var cells: [[Cell]]
    var ships: [Ship]
    var showFinishGameAlert: Bool
    var fireStrokeArray: [[Bool]]

    init(_ player: PlayerData) {
        self.name = player.name
        self.cells = player.cells
        self.ships = player.ships
        self.showFinishGameAlert = player.showFinishGameAlert
        self.fireStrokeArray = player.fireStrokeArray
    }

    /// Restores this snapshot into an existing `PlayerData`. `name` is a `let`
    /// on `PlayerData` and is intentionally left untouched.
    func restore(into player: PlayerData) {
        player.cells = cells
        player.ships = ships
        player.showFinishGameAlert = showFinishGameAlert
        // Always clear the transient fire-stroke overlay on restore: if the app
        // was killed mid-shot a cell could otherwise stay stuck with a red halo.
        player.fireStrokeArray = fireStrokeArray.map { $0.map { _ in false } }
    }
}

/// A serializable snapshot of an entire match.
struct GameSnapshot: Codable, Sendable {
    var schemaVersion: Int
    var difficulty: Int
    var enemysTurn: Bool
    var gameIsActive: Bool
    var manualShipArrangement: Bool
    var potentialCellsForFinishingDamagedShip: [Coordinate]?
    var player: PlayerSnapshot
    var enemy: PlayerSnapshot

    init(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.schemaVersion = 1
        self.difficulty = appState.difficulty
        self.enemysTurn = appState.enemysTurn
        self.gameIsActive = appState.gameIsActive
        self.manualShipArrangement = appState.manualShipArrangement
        self.potentialCellsForFinishingDamagedShip =
            appState.potentialCellsForFinishingDamagedShip?.map(Coordinate.init)
        self.player = PlayerSnapshot(player)
        self.enemy = PlayerSnapshot(enemy)
    }

    /// Applies this snapshot back onto the live game objects.
    func apply(to appState: AppState, player: PlayerData, enemy: PlayerData) {
        appState.difficulty = difficulty
        appState.enemysTurn = enemysTurn
        appState.gameIsActive = gameIsActive
        appState.manualShipArrangement = manualShipArrangement
        appState.potentialCellsForFinishingDamagedShip =
            potentialCellsForFinishingDamagedShip?.map { $0.tuple }
        self.player.restore(into: player)
        self.enemy.restore(into: enemy)
    }
}
