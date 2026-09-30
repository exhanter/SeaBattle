//
//  PaperStore.swift
//  SeaBattle
//
//  R3.1: the saved paper game. A separate single slot next to `GameStore`
//  rather than a mode flag inside `GameSnapshot`: the two matches are
//  different things (the paper game has no computer, no hints and a board
//  without a fleet), and a player can have one of each open at the same time —
//  "Continue" then asks which one (spec 3.1).
//
//  The paper game is saved after **every** move. It has no opponent turn to
//  wait for, so every point between moves is a stable one.
//

import Foundation

struct PaperSave: Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = Self.currentSchemaVersion
    var game: PaperGame
}

enum PaperStore {

    private static let fileName = "PaperGame.json"

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    /// Same discipline as `GameStore`: one serial queue, so `clear()` after
    /// `save(_:)` is never overtaken and a finished game cannot come back.
    private static let queue = DispatchQueue(label: "nl.brapps.SeaBattle.PaperStore")

    static var hasSavedGame: Bool {
        queue.sync { FileManager.default.fileExists(atPath: fileURL.path) }
    }

    static func save(_ game: PaperGame) {
        let save = PaperSave(game: game)
        queue.async {
            do {
                let directory = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(save)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                Log.store.error("PaperStore save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The saved game, or `nil` when there is none, it does not decode, or it
    /// was written in another format — discarded rather than resumed broken.
    static func load() -> PaperGame? {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let save = try? JSONDecoder().decode(PaperSave.self, from: data) else {
                return nil
            }
            guard save.schemaVersion == PaperSave.currentSchemaVersion else {
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
