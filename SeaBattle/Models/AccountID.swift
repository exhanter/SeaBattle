//
//  AccountID.swift
//  SeaBattle
//
//  A stable per-account identifier used only to detect a SAME-account match
//  (my iPhone + my iPad) so those games award no points. Derived from the
//  iCloud ubiquity token when available (same across a person's devices),
//  otherwise a persisted per-install UUID. Phase 3 will switch to
//  `CKContainer.fetchUserRecordID()` once the CloudKit capability is added.
//

import Foundation
import CryptoKit

enum AccountID {
    private static let fallbackKey = "localAccountID.fallback"

    static func current() -> String {
        if let token = FileManager.default.ubiquityIdentityToken,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true),
           !data.isEmpty {
            let digest = SHA256.hash(data: data)
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            return "icloud-" + String(hex.prefix(24))
        }
        if let existing = UserDefaults.standard.string(forKey: fallbackKey) { return existing }
        let generated = "local-" + UUID().uuidString
        UserDefaults.standard.set(generated, forKey: fallbackKey)
        return generated
    }
}
