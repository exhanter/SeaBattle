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

    /// Every touch of the file goes through this one serial queue, so the file
    /// is only ever written from one thread and operations land in the order
    /// they were issued.
    ///
    /// Order is the reason this is a serial queue rather than a detached task:
    /// `clear()` after `save(_:)` must not be overtaken, or a finished match
    /// would come back from the dead. `save` hands off and returns (audit
    /// finding B17 — it used to encode and write on the main actor on every
    /// shot); the rarer `load`, `clear` and `hasSavedGame` wait for the queue
    /// to drain, so a caller always sees its own earlier writes.
    private static let queue = DispatchQueue(label: "nl.brapps.SeaBattle.GameStore")

    /// Whether a saved game currently exists on disk.
    static var hasSavedGame: Bool {
        queue.sync { FileManager.default.fileExists(atPath: fileURL.path) }
    }

    /// Writes the snapshot to disk atomically, overwriting any previous save.
    /// Returns immediately; the encode and the write happen off the main thread.
    static func save(_ snapshot: GameSnapshot) {
        queue.async {
            do {
                let directory = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                Log.store.error("GameStore save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Loads the saved game, or `nil` if there is none, it can't be decoded, or
    /// it was written by a different version of the format.
    ///
    /// The version was recorded but never checked before R0.4 (audit finding
    /// B12), so a format change would have decoded into nonsense. A save from
    /// another version is discarded rather than resumed — losing one
    /// in-progress game is a far better outcome than restoring a broken one.
    static func load() -> GameSnapshot? {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
                return nil
            }
            guard snapshot.schemaVersion == GameSnapshot.currentSchemaVersion else {
                Log.store.notice("Discarding a save in format v\(snapshot.schemaVersion), expected v\(GameSnapshot.currentSchemaVersion)")
                removeFile()
                return nil
            }
            return snapshot
        }
    }

    /// Removes the saved game (on game over, "New game" or "Stop game").
    static func clear() {
        queue.sync { removeFile() }
    }

    /// Must only be called on `queue` — `clear()` and `load()` are already on
    /// it, and calling `sync` again from inside would deadlock.
    private static func removeFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
