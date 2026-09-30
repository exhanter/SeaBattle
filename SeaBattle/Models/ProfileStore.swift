//
//  ProfileStore.swift
//  SeaBattle
//
//  Saved local players (name + avatar, up to 10 per account) for quick reuse in
//  hot-seat setup. PINs are NOT stored here — they are chosen per session in
//  HotSeatGame. Persisted to UserDefaults; account sync arrives with Phase 3.
//

import Foundation
import Observation
import CryptoKit

@MainActor
@Observable
final class ProfileStore {

    static let shared = ProfileStore()
    static let maxProfiles = 10

    private static let defaultsKey = "playerProfiles"
    private static let modifiedKey = "playerProfiles.modified"
    private nonisolated static let salt = "SeaBattle.pin.v1."

    private(set) var profiles: [PlayerProfile]
    private(set) var lastModified: Date

    /// Called after a LOCAL change so the sync layer can push.
    @ObservationIgnored var didChange: (() -> Void)?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([PlayerProfile].self, from: data) {
            self.profiles = decoded
        } else {
            self.profiles = []
        }
        self.lastModified = (UserDefaults.standard.object(forKey: Self.modifiedKey) as? Date) ?? .distantPast
    }

    // MARK: - Sync bridge

    func exportData() -> Data? { try? JSONEncoder().encode(profiles) }

    func applyRemote(_ data: Data, modified: Date) {
        guard let decoded = try? JSONDecoder().decode([PlayerProfile].self, from: data) else { return }
        profiles = decoded
        lastModified = modified
        writeLocal()
    }

    var canAddMore: Bool { profiles.count < Self.maxProfiles }

    /// Salted SHA-256 hash of a PIN, as a hex string. Used by HotSeatGame to
    /// compare session PINs without keeping the plaintext. Nonisolated: the
    /// hot-seat rules (`DuelGame`) are a plain value type off the main actor.
    nonisolated static func hash(pin: String) -> String {
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Creates or updates a saved player by name (case-insensitive). RETURNS the
    /// stored profile, or nil if the name is blank. A full roster forgets the
    /// player who played longest ago rather than refusing the new one.
    @discardableResult
    func upsert(name: String, avatar: String, colorIndex: Int? = nil) -> PlayerProfile? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let index = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            profiles[index].name = trimmed
            profiles[index].avatar = avatar
            if let colorIndex { profiles[index].colorIndex = colorIndex }
            // Last played goes last: "Played before" shows the newest first.
            profiles.append(profiles.remove(at: index))
            persist()
            return profiles.last
        }
        // A full roster forgets the player who played longest ago.
        if !canAddMore { profiles.removeFirst() }
        let profile = PlayerProfile(name: trimmed, avatar: avatar, colorIndex: colorIndex)
        profiles.append(profile)
        persist()
        return profile
    }

    func remove(_ profile: PlayerProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    private func persist() {
        lastModified = Date()
        writeLocal()
        didChange?()
    }

    private func writeLocal() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        UserDefaults.standard.set(lastModified, forKey: Self.modifiedKey)
    }
}
