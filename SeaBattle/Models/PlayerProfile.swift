//
//  PlayerProfile.swift
//  SeaBattle
//
//  Phase 0: local player identity model. Reused by hot-seat play (Phase 5a),
//  networked play (Phase 5) and the points/hints system (Phase 6). Up to 10
//  profiles per account will be enforced at the storage layer.
//

import Foundation

/// A named local player. Synced to CloudKit / backend in later phases.
struct PlayerProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// Salted SHA-256 hash of the player's PIN, or `nil` when no PIN is set.
    /// The plaintext PIN is never stored; see the hot-seat privacy handoff
    /// (Phase 5a). Persisted in the Keychain in the storage layer.
    var pinHash: String?
    var stats: PlayerStats

    init(id: UUID = UUID(), name: String, pinHash: String? = nil, stats: PlayerStats = PlayerStats()) {
        self.id = id
        self.name = name
        self.pinHash = pinHash
        self.stats = stats
    }
}

/// Per-player aggregate statistics and the difficulty-bucketed points wallet.
struct PlayerStats: Codable, Hashable, Sendable {
    /// Wins per difficulty, keyed by `DifficultyLevel.rawValue`. Tracked for ALL
    /// users (free included) so players can show off; resettable in the UI.
    var winsByDifficulty: [String: Int]
    var losses: Int
    /// Single shared points wallet (Phase 6). The win reward and the hint cost
    /// vary by difficulty, but points themselves are fungible across levels.
    var points: Int

    /// Total wins across all difficulties.
    var totalWins: Int { winsByDifficulty.values.reduce(0, +) }

    init(winsByDifficulty: [String: Int] = [:], losses: Int = 0, points: Int = 0) {
        self.winsByDifficulty = winsByDifficulty
        self.losses = losses
        self.points = points
    }
}
