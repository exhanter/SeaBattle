//
//  GameStoreTests.swift
//  SeaBattleTests
//
//  R0.4 changed the saved game twice: the format version is now checked on load
//  (audit finding B12) and the write no longer happens on the main actor
//  (finding B17). Both are the kind of change that fails silently — a save that
//  quietly never arrives looks exactly like "no game to continue" — so the
//  round trip and the ordering guarantees are pinned down here.
//

import Foundation
import Testing
@testable import SeaBattle

/// Serialized on purpose: there is one saved-game file and every test in here
/// writes it, so running them at the same time would have them clobber each
/// other rather than test anything.
@MainActor
@Suite(.serialized)
struct GameStoreTests {

    /// A snapshot of a match in progress, with one shot fired at each side.
    private func snapshot(difficulty: Int = 1) -> GameSnapshot {
        let appState = AppState()
        appState.difficulty = difficulty
        appState.gameIsActive = true
        let player = PlayerData(side: .you)
        let enemy = PlayerData(side: .foe)
        player.shipsRandomArrangement()
        enemy.shipsRandomArrangement()

        for side in [player, enemy] {
            var board = side.coreBoard
            board.apply(shotAt: Coordinate(side.ships[0].coordinates[0]))
            side.apply(board)
        }
        return GameSnapshot(appState: appState, player: player, enemy: enemy)
    }

    @Test("A saved game comes back the way it went in")
    func roundTrip() {
        GameStore.clear()
        let original = snapshot(difficulty: 3)

        GameStore.save(original)
        #expect(GameStore.hasSavedGame)

        let loaded = GameStore.load()
        #expect(loaded?.difficulty == 3)
        #expect(loaded?.gameIsActive == true)
        #expect(loaded?.player.ships.count == FleetLayout.shipCount)
        #expect(loaded?.enemy.ships.count == FleetLayout.shipCount)

        GameStore.clear()
    }

    @Test("Clearing right after saving really clears")
    func clearIsNotOvertakenByAnInFlightSave() {
        // `save` hands the write to a background queue and returns, so a
        // `clear` issued immediately afterwards has to land after it. If the
        // two raced, a finished match would reappear as "Continue".
        GameStore.save(snapshot())
        GameStore.clear()

        #expect(!GameStore.hasSavedGame)
        #expect(GameStore.load() == nil)
    }

    @Test("The last save wins")
    func savesApplyInOrder() {
        GameStore.clear()
        GameStore.save(snapshot(difficulty: 0))
        GameStore.save(snapshot(difficulty: 2))

        #expect(GameStore.load()?.difficulty == 2)
        GameStore.clear()
    }

    @Test("A save in an older format is discarded rather than resumed")
    func foreignSchemaVersionIsRejected() {
        GameStore.clear()
        var stale = snapshot()
        stale.schemaVersion = GameSnapshot.currentSchemaVersion - 1
        GameStore.save(stale)

        #expect(GameStore.load() == nil, "A save from another format must not load")
        // It is also removed, so the menu stops offering to continue it.
        #expect(!GameStore.hasSavedGame)
    }

    @Test("No saved game means nothing to load")
    func emptyStore() {
        GameStore.clear()
        #expect(!GameStore.hasSavedGame)
        #expect(GameStore.load() == nil)
    }
}
