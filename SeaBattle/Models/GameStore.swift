//
//  GameStore.swift
//  SeaBattle
//
//  Phase 1: single-slot persistence of an in-progress game for ALL users
//  (free and premium). The whole match is stored as one `GameSnapshot` JSON
//  file in Application Support. Multiple named slots for premium land in a
//  later phase; this is the free "one game, one slot" baseline.
//

import Foundation

/// Stateless file-based store for the current saved game.
enum GameStore {

    private static let fileName = "SavedGame.json"

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    /// Whether a saved game currently exists on disk.
    static var hasSavedGame: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Writes the snapshot to disk atomically, overwriting any previous save.
    static func save(_ snapshot: GameSnapshot) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("GameStore save error: \(error.localizedDescription)")
        }
    }

    /// Loads the saved game, or `nil` if there is none / it can't be decoded.
    static func load() -> GameSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    /// Removes the saved game (on game over, "New game" or "Stop game").
    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
