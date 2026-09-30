//
//  StatisticsTests.swift
//  SeaBattleTests
//
//  R0.7: statistics are kept per mode. What matters here is that a win over a
//  person on the network is NOT a win over the computer's expert level (audit
//  finding A7), and that history saved by an older build still loads.
//

import Testing
import Foundation
@testable import SeaBattle

@MainActor
struct StatisticsTests {

    // MARK: - Rows

    @Test func everyRowHasItsOwnStorageKey() {
        let keys = StatKey.tracked.map(\.storageKey)
        #expect(Set(keys).count == keys.count)
        // Frozen strings: changing one orphans everybody's saved history.
        #expect(StatKey.computer(.expert).storageKey == "computer.expert")
        #expect(StatKey.nearby.storageKey == "nearby")
        #expect(StatKey.online.storageKey == "online")
    }

    @Test func hotSeatIsNotTrackedAndIsNotAModeRow() {
        #expect(GameMode.hotSeat.isTracked == false)
        #expect(StatKey.tracked.contains { $0.mode == .hotSeat } == false)
        // Every other mode does get a row, in menu order.
        #expect(StatKey.tracked.map(\.mode) == [.computer, .computer, .computer, .computer,
                                                .paper, .nearby, .online])
    }

    @Test func aNetworkWinPaysTheExpertRateButNotInTheExpertRow() {
        #expect(StatKey.nearby.pointsForWin == AppState.DifficultyLevel.expert.pointsValue)
        #expect(StatKey.online.pointsForWin == AppState.DifficultyLevel.expert.pointsValue)
        // The paper game is scored by the player, so it buys nothing.
        #expect(StatKey.paper.pointsForWin == 0)
    }

    // MARK: - Counting

    @Test func winsAndLossesLandInTheirOwnRows() {
        var stats = PlayerStats()
        stats.addWin(.computer(.hard))
        stats.addWin(.computer(.hard))
        stats.addLoss(.computer(.hard))
        stats.addWin(.online)
        stats.addLoss(.nearby)

        #expect(stats.record(.computer(.hard)) == StatRecord(wins: 2, losses: 1))
        #expect(stats.record(.online) == StatRecord(wins: 1, losses: 0))
        #expect(stats.record(.nearby) == StatRecord(wins: 0, losses: 1))
        // The row A7 used to fill is untouched.
        #expect(stats.record(.computer(.expert)) == StatRecord())
        #expect(stats.record(.paper) == StatRecord())
    }

    @Test func theComputerModeAddsUpItsFourLevels() {
        var stats = PlayerStats()
        stats.addWin(.computer(.easy))
        stats.addWin(.computer(.expert))
        stats.addLoss(.computer(.medium))
        stats.addWin(.nearby)

        #expect(stats.record(for: .computer) == StatRecord(wins: 2, losses: 1))
        #expect(stats.record(for: .nearby) == StatRecord(wins: 1, losses: 0))
        #expect(stats.record(for: .online) == StatRecord())
    }

    @Test func theSummaryCountsEveryRow() {
        var stats = PlayerStats()
        stats.addWin(.computer(.easy))
        stats.addWin(.online)
        stats.addWin(.online)
        stats.addLoss(.nearby)

        #expect(stats.totalWins == 3)
        #expect(stats.totalLosses == 1)
        #expect(stats.totalGames == 4)
        #expect(stats.winShare == 0.75)
    }

    @Test func anEmptyHistoryHasNoWinShare() {
        #expect(PlayerStats().winShare == nil)
        #expect(PlayerStats().totalGames == 0)
        #expect(StatRecord().winShare == nil)
    }

    // MARK: - Saved history

    @Test func historyFromBeforeR0_7Migrates() throws {
        // Exactly what the pre-R0.7 build wrote: wins per level, one global
        // loss counter, the wallet.
        let legacy = """
        {"winsByDifficulty":{"easy":2,"expert":5},"losses":7,"points":41}
        """.data(using: .utf8)!
        let stats = try JSONDecoder().decode(PlayerStats.self, from: legacy)

        #expect(stats.points == 41)
        #expect(stats.record(.computer(.easy)).wins == 2)
        #expect(stats.record(.computer(.expert)).wins == 5)
        #expect(stats.totalWins == 7)
        // Those 5 expert wins may well have been network wins, but there is no
        // way to tell now, so they stay where they were written.
        // The losses had no level, so they belong to no row and only to the
        // summary — inventing a level for them would be inventing history.
        #expect(stats.unattributedLosses == 7)
        #expect(stats.record(.computer(.expert)).losses == 0)
        #expect(stats.totalLosses == 7)
        #expect(stats.totalGames == 14)
    }

    @Test func statsSurviveARoundTrip() throws {
        var stats = PlayerStats(points: 12)
        stats.addWin(.computer(.medium))
        stats.addLoss(.online)
        stats.unattributedLosses = 3

        let data = try JSONEncoder().encode(stats)
        #expect(try JSONDecoder().decode(PlayerStats.self, from: data) == stats)
    }

    /// A build from before R0.7 sharing the same iCloud record must still be
    /// able to read what this one writes — hence the legacy mirror.
    @Test func whatWeWriteIsStillReadableByTheOldShape() throws {
        var stats = PlayerStats()
        stats.addWin(.computer(.hard))
        stats.addLoss(.computer(.hard))
        stats.addWin(.online)
        stats.addLoss(.nearby)

        let json = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(stats))
        let object = try #require(json as? [String: Any])
        #expect(object["winsByDifficulty"] as? [String: Int] == ["hard": 1])
        #expect(object["losses"] as? Int == 2)
    }

    // MARK: - The store

    @Test func theStoreAwardsThePointsOfTheRowItRecords() {
        let store = ProgressStore.shared
        let restore = store.exportData()
        defer { if let restore { store.applyRemote(restore, modified: store.lastModified) } }

        let before = store.stats
        store.recordWin(.computer(.easy))
        #expect(store.points == before.points + AppState.DifficultyLevel.easy.pointsValue)
        #expect(store.record(.computer(.easy)).wins == before.record(.computer(.easy)).wins + 1)

        store.recordWin(.nearby)
        #expect(store.points == before.points + AppState.DifficultyLevel.easy.pointsValue
                + AppState.DifficultyLevel.expert.pointsValue)
        #expect(store.record(.nearby).wins == before.record(.nearby).wins + 1)
        // The whole point of R0.7: the expert row did not move.
        #expect(store.record(.computer(.expert)) == before.record(.computer(.expert)))
    }

    @Test func theStoreIgnoresUntrackedModes() {
        let store = ProgressStore.shared
        let restore = store.exportData()
        defer { if let restore { store.applyRemote(restore, modified: store.lastModified) } }

        let before = store.stats
        store.recordWin(.hotSeat)
        store.recordLoss(.hotSeat)
        #expect(store.stats == before)
    }

    // MARK: - A whole networked match

    /// Plays a nearby match to its end between two DIFFERENT accounts (the
    /// other tests use one account on purpose, to stay off the real store) and
    /// checks which rows moved.
    @Test func aFinishedNearbyMatchIsFiledUnderNearby() {
        let store = ProgressStore.shared
        let restore = store.exportData()
        defer { if let restore { store.applyRemote(restore, modified: store.lastModified) } }

        let before = store.stats

        let (a, b) = LoopbackTransport.pair()
        let host = NetMatch(transport: a, statKey: .nearby,
                            me: NetMatch.hello(name: "H", glyph: "h", colorIndex: 0, accountID: "host"),
                            pacing: .instant)
        let guest = NetMatch(transport: b, statKey: .nearby,
                             me: NetMatch.hello(name: "G", glyph: "g", colorIndex: 1, accountID: "guest"),
                             pacing: .instant)
        for match in [host, guest] {
            match.soundOn = false
            match.editor = FleetEditor(ships: FleetLayout.canonicalLayout())
            match.start()
            match.finishArrangement()
        }
        #expect(host.game.isSameAccount == false)

        // Hulls only, so the shooter keeps the turn all the way through.
        let (shooter, target) = host.isMyTurn ? (host, guest) : (guest, host)
        for cell in target.game.own.ships.flatMap(\.cells) {
            shooter.tap(cell)
        }
        #expect(shooter.game.winner == .you)
        #expect(target.game.winner == .foe)

        // Both peers ran in this process, so the local store saw both results:
        // one nearby win and one nearby loss, and nothing anywhere else.
        #expect(store.record(.nearby).wins == before.record(.nearby).wins + 1)
        #expect(store.record(.nearby).losses == before.record(.nearby).losses + 1)
        #expect(store.record(.computer(.expert)) == before.record(.computer(.expert)))
        #expect(store.record(for: .computer) == before.record(for: .computer))
        #expect(store.record(.online) == before.record(.online))
    }
}
