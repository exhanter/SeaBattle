//
//  ProgressStore.swift
//  SeaBattle
//
//  Phase 6: the local player's progress — wins per difficulty (tracked for ALL
//  users, free included), losses, and a single shared points wallet. Points are
//  earned on every win (amount depends on difficulty) and spent on hints. Kept
//  as one persisted record for now; per-profile progress arrives with accounts
//  (Phase 3) and hot-seat (Phase 5a).
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

    func wins(for level: AppState.DifficultyLevel) -> Int {
        stats.winsByDifficulty[level.rawValue] ?? 0
    }

    // MARK: - Mutations

    /// Records a win at the given difficulty and awards its points.
    func recordWin(at level: AppState.DifficultyLevel) {
        stats.winsByDifficulty[level.rawValue, default: 0] += 1
        stats.points += level.pointsValue
        persist()
    }

    func recordLoss() {
        stats.losses += 1
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
