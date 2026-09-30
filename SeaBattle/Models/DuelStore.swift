//
//  DuelStore.swift
//  SeaBattle
//
//  R3.2: the saved two-players-on-one-device match (`DuelGame`), a single slot
//  next to `GameStore` and `PaperStore`. Saved after every move and every
//  handoff, like the paper game: there is no computer turn to wait for, so
//  every point between moves is a stable one.
//
//  TRANSITIONAL (ПЕРЕХОДНОЕ): the old hot-seat screens still used on iPad keep
//  their own `HotSeatStore` until R3.2b moves the iPad onto `DuelGame` too.
//

import Foundation

struct DuelSave: Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = Self.currentSchemaVersion
    var game: DuelGame
}

enum DuelStore {

    private static let fileName = "DuelGame.json"

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    /// Same discipline as `GameStore`: one serial queue, so `clear()` after
    /// `save(_:)` is never overtaken and a finished match cannot come back.
    private static let queue = DispatchQueue(label: "nl.brapps.SeaBattle.DuelStore")

    static var hasSavedGame: Bool {
        queue.sync { FileManager.default.fileExists(atPath: fileURL.path) }
    }

    static func save(_ game: DuelGame) {
        let save = DuelSave(game: game)
        queue.async {
            do {
                let directory = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(save)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                Log.store.error("DuelStore save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The saved match, or `nil` when there is none, it does not decode, or it
    /// was written in another format — discarded rather than resumed broken.
    static func load() -> DuelGame? {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let save = try? JSONDecoder().decode(DuelSave.self, from: data) else {
                return nil
            }
            guard save.schemaVersion == DuelSave.currentSchemaVersion else {
                removeFile()
                return nil
            }
            return save.game
        }
    }

    static func clear() {
        queue.sync { removeFile() }
    }

    /// Only on `queue`.
    private static func removeFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
