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
///
/// Since R0.7 a finished match is filed under its own row (`StatKey`) instead of
/// under a difficulty level, so a win over a person on the network no longer
/// lands in the "computer · expert" column (audit finding A7). Tracked for ALL
/// users (free included) so players can show off; resettable in the UI.
struct PlayerStats: Codable, Hashable, Sendable {
    /// Wins and losses per row, keyed by `StatKey.storageKey`.
    var records: [String: StatRecord]
    /// Losses recorded before R0.7, when a loss was one global counter with no
    /// mode and no level attached. They still count in the summary, and they
    /// belong to no row — guessing a level for them would be inventing history.
    var unattributedLosses: Int
    /// Single shared points wallet (Phase 6). The win reward and the hint cost
    /// vary by difficulty, but points themselves are fungible across levels.
    var points: Int

    init(records: [String: StatRecord] = [:], unattributedLosses: Int = 0, points: Int = 0) {
        self.records = records
        self.unattributedLosses = unattributedLosses
        self.points = points
    }

    // MARK: - Reads

    func record(_ key: StatKey) -> StatRecord { records[key.storageKey] ?? StatRecord() }

    /// The whole mode as one row: for `.computer` that is the four levels added
    /// up, for the rest it is the single row itself.
    func record(for mode: GameMode) -> StatRecord {
        StatKey.tracked
            .filter { $0.mode == mode }
            .reduce(into: StatRecord()) { sum, key in
                let row = record(key)
                sum.wins += row.wins
                sum.losses += row.losses
            }
    }

    var totalWins: Int { records.values.reduce(0) { $0 + $1.wins } }
    var totalLosses: Int { records.values.reduce(0) { $0 + $1.losses } + unattributedLosses }
    var totalGames: Int { totalWins + totalLosses }

    /// Share of games won, 0…1, or `nil` when nothing has been played yet.
    var winShare: Double? {
        totalGames > 0 ? Double(totalWins) / Double(totalGames) : nil
    }

    // MARK: - Mutations

    mutating func addWin(_ key: StatKey) { records[key.storageKey, default: StatRecord()].wins += 1 }
    mutating func addLoss(_ key: StatKey) { records[key.storageKey, default: StatRecord()].losses += 1 }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case records, unattributedLosses, points
        // Pre-R0.7 shape. Read when migrating, and still WRITTEN, so a build
        // from before R0.7 sharing the same iCloud record (last-writer-wins)
        // keeps seeing sensible numbers instead of failing to decode.
        case winsByDifficulty, losses
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        if let records = try c.decodeIfPresent([String: StatRecord].self, forKey: .records) {
            self.records = records
            unattributedLosses = try c.decodeIfPresent(Int.self, forKey: .unattributedLosses) ?? 0
        } else {
            // Migration: wins keep their level, the global loss counter has
            // nowhere to go and becomes `unattributedLosses`.
            let legacy = try c.decodeIfPresent([String: Int].self, forKey: .winsByDifficulty) ?? [:]
            var migrated: [String: StatRecord] = [:]
            for level in AppState.DifficultyLevel.allCases {
                if let wins = legacy[level.rawValue], wins != 0 {
                    migrated[StatKey.computer(level).storageKey] = StatRecord(wins: wins, losses: 0)
                }
            }
            self.records = migrated
            unattributedLosses = try c.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(records, forKey: .records)
        try c.encode(unattributedLosses, forKey: .unattributedLosses)
        try c.encode(points, forKey: .points)
        // Legacy mirror — see `CodingKeys`. Only the computer levels fit in it,
        // which is exactly right: an old build never knew any other column.
        var legacy: [String: Int] = [:]
        for level in AppState.DifficultyLevel.allCases {
            let wins = record(.computer(level)).wins
            if wins != 0 { legacy[level.rawValue] = wins }
        }
        try c.encode(legacy, forKey: .winsByDifficulty)
        try c.encode(totalLosses, forKey: .losses)
    }
}
