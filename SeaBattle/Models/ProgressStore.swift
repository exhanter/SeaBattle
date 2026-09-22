//
//  ProgressStore.swift
//  SeaBattle
//
//  Phase 6: the local player's progress — wins and losses per statistics row
//  (tracked for ALL users, free included) and a single shared points wallet.
//  Points are earned on every win (amount depends on the row) and spent on
//  hints. Kept as one persisted record for now; per-profile progress arrives
//  with accounts (Phase 3) and hot-seat (Phase 5a).
//
//  R0.7: a row is a `StatKey` — the mode, plus the level for the computer — so
//  the modes are counted apart, as the design shows them (spec 4.9).
//

import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {

    static let shared = ProgressStore()

    private static let defaultsKey = "playerStats"
    private static let modifiedKey = "playerStats.modified"

    private(set) var stats: PlayerStats
    /// When the local data last changed — used for last-writer-wins CloudKit sync.
    private(set) var lastModified: Date

    /// Called after a LOCAL change so the sync layer can push. Not called when
    /// applying a remote update.
    @ObservationIgnored var didChange: (() -> Void)?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            self.stats = decoded
        } else {
            self.stats = PlayerStats()
        }
        self.lastModified = (UserDefaults.standard.object(forKey: Self.modifiedKey) as? Date) ?? .distantPast
    }

    // MARK: - Sync bridge

    func exportData() -> Data? { try? JSONEncoder().encode(stats) }

    /// Applies a newer copy pulled from CloudKit (does not re-trigger a push).
    func applyRemote(_ data: Data, modified: Date) {
        guard let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) else { return }
        stats = decoded
        lastModified = modified
        writeLocal()
    }

    // MARK: - Reads

    var points: Int { stats.points }

    /// Wins and losses in one row of the statistics.
    func record(_ key: StatKey) -> StatRecord { stats.record(key) }

    /// Wins and losses in a whole mode — the four levels added up, for the
    /// computer.
    func record(for mode: GameMode) -> StatRecord { stats.record(for: mode) }

    func wins(for level: AppState.DifficultyLevel) -> Int { stats.record(.computer(level)).wins }

    // MARK: - Mutations

    /// Records a win in the given row and awards the points it pays out.
    ///
    /// The row carries the mode, so a network win is counted as a network win;
    /// before R0.7 it was filed as a win over the expert (audit finding A7).
    func recordWin(_ key: StatKey) {
        guard key.mode.isTracked else { return }
        stats.addWin(key)
        stats.points += key.pointsForWin
        persist()
    }

    func recordLoss(_ key: StatKey) {
        guard key.mode.isTracked else { return }
        stats.addLoss(key)
        persist()
    }

    /// Spends `amount` points if the balance allows. RETURNS: whether it succeeded.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard stats.points >= amount else { return false }
        stats.points -= amount
        persist()
        return true
    }

    /// Adds points (win reward, a gift from another player, or an in-app purchase).
    func addPoints(_ amount: Int) {
        stats.points += amount
        persist()
    }

    /// Clears all statistics and points.
    func reset() {
        stats = PlayerStats()
        persist()
    }

    private func persist() {
        lastModified = Date()
        writeLocal()
        didChange?()
    }

    private func writeLocal() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        UserDefaults.standard.set(lastModified, forKey: Self.modifiedKey)
    }
}
