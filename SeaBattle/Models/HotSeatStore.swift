//
//  HotSeatStore.swift
//  SeaBattle
//
//  Phase 5a: persists the current hot-seat SESSION (both players, their boards,
//  the win tally and where the match is) so it survives app relaunch. The
//  session lives indefinitely; it's cleared only when the players tap Done or
//  start / delete a session from the Two Players screen.
//

import Foundation

enum HotSeatStore {

    private static let fileName = "HotSeatSession.json"

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    static var hasSession: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func save(_ snapshot: HotSeatSnapshot) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("HotSeatStore save error: \(error.localizedDescription)")
        }
    }

    static func load() -> HotSeatSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(HotSeatSnapshot.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
