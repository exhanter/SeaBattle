//
//  PlayerProfile.swift
//  SeaBattle
//
//  A saved local player: name + avatar (up to 10 per account). The hot-seat PIN
//  is intentionally NOT stored here — it is session-only (see HotSeatGame).
//  Photos / Genmoji avatars can be added later; for now the avatar is one of a
//  fixed set of SF Symbols.
//

import Foundation

/// The fixed set of built-in avatars (SF Symbol names).
enum HotSeatAvatars {
    static let symbols = [
        "star.fill", "crown.fill", "bolt.fill", "flame.fill", "leaf.fill",
        "tortoise.fill", "hare.fill", "fish.fill", "pawprint.fill", "heart.fill"
    ]
}

struct PlayerProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var avatar: String
    /// Legacy field; no longer persisted for hot-seat (PIN is session-only).
    var pinHash: String?
    var stats: PlayerStats

    init(id: UUID = UUID(),
         name: String,
         avatar: String = HotSeatAvatars.symbols[0],
         pinHash: String? = nil,
         stats: PlayerStats = PlayerStats()) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.pinHash = pinHash
        self.stats = stats
    }

    // Lenient decoding so profiles saved before `avatar` existed still load.
    private enum CodingKeys: String, CodingKey { case id, name, avatar, pinHash, stats }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar) ?? HotSeatAvatars.symbols[0]
        pinHash = try c.decodeIfPresent(String.self, forKey: .pinHash)
        stats = try c.decodeIfPresent(PlayerStats.self, forKey: .stats) ?? PlayerStats()
    }
}

/// Per-player aggregate statistics and the shared points wallet.
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
