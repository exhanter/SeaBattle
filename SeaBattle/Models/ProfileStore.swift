//
//  ProfileStore.swift
//  SeaBattle
//
//  Phase 5a: saved local players (up to 10 per account) with an optional PIN
//  used for the hot-seat privacy handoff. The plaintext PIN is never stored —
//  only a salted SHA-256 hash. Persisted to UserDefaults for now; moving the
//  hash to the Keychain and syncing profiles via the account is a later step
//  (Phase 3).
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
    private static let salt = "SeaBattle.pin.v1."

    private(set) var profiles: [PlayerProfile]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([PlayerProfile].self, from: data) {
            self.profiles = decoded
        } else {
            self.profiles = []
        }
    }

    var canAddMore: Bool { profiles.count < Self.maxProfiles }

    /// Salted SHA-256 hash of a PIN, as a hex string.
    static func hash(pin: String) -> String {
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Whether the supplied PIN matches a profile (a profile with no PIN always matches).
    func verify(_ profile: PlayerProfile, pin: String) -> Bool {
        guard let stored = profile.pinHash else { return true }
        return stored == Self.hash(pin: pin)
    }

    /// Creates or updates a profile by name. A non-empty `pin` sets/updates the
    /// PIN; an empty `pin` clears it. RETURNS: the stored profile (or nil if the
    /// name is blank or the roster is full for a new name).
    @discardableResult
    func upsert(name: String, pin: String) -> PlayerProfile? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let pinHash = pin.isEmpty ? nil : Self.hash(pin: pin)
        if let index = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            profiles[index].name = trimmed
            profiles[index].pinHash = pinHash
            persist()
            return profiles[index]
        }
        guard canAddMore else { return nil }
        let profile = PlayerProfile(name: trimmed, pinHash: pinHash)
        profiles.append(profile)
        persist()
        return profile
    }

    func remove(_ profile: PlayerProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
