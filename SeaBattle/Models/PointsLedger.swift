//
//  PointsLedger.swift
//  SeaBattle
//
//  R4.1: the history of the points wallet. Until now the wallet was one number;
//  the designed wallet (spec 4.10) shows the last five movements and a full
//  list, so every change of the balance now leaves an entry behind.
//
//  The ledger lives inside `PlayerStats`, so it travels with the balance in
//  the same CloudKit record (last-writer-wins replaces both at once and they
//  never disagree). Builds before R4.1 ignore the unknown key.
//

import Foundation

/// One movement of the balance.
struct PointsEntry: Codable, Hashable, Sendable, Identifiable {
    enum Kind: Codable, Hashable, Sendable {
        /// A win in a statistics row, by `StatKey.storageKey` — the same frozen
        /// strings as the statistics, so the row survives a rename of a case.
        case win(row: String)
        /// Hints bought in a row on the same day, merged into one line
        /// («Подсказка, 2 раза» in the mockup).
        case hints(count: Int)
        /// The opponent bought a hint over the network and revealed one of my
        /// ships; I am paid the price (`NetGame`). Merged the same way.
        case compensation(count: Int)
    }

    var id = UUID()
    var date: Date
    var kind: Kind
    /// Signed: a hint is negative.
    var amount: Int

    /// The row of a win, back as a key; `nil` for anything else and for a row
    /// this build does not know.
    var winRow: StatKey? {
        if case .win(let row) = kind { return StatKey(storageKey: row) }
        return nil
    }
}

struct PointsLedger: Codable, Hashable, Sendable {
    static let currentVersion = 1
    /// How many movements are kept. «Все начисления» shows them all; older ones
    /// fall off the end. The balance itself is never derived from the ledger,
    /// so a short history cannot change it.
    static let capacity = 100

    private(set) var version = Self.currentVersion
    /// Newest first.
    private(set) var entries: [PointsEntry] = []

    init(entries: [PointsEntry] = []) {
        self.entries = Array(entries.prefix(Self.capacity))
    }

    /// The last movements the wallet shows on its first page.
    var recent: [PointsEntry] { Array(entries.prefix(5)) }

    mutating func addWin(_ key: StatKey, points: Int, at date: Date) {
        guard points != 0 else { return }
        push(PointsEntry(date: date, kind: .win(row: key.storageKey), amount: points))
    }

    mutating func addHint(cost: Int, at date: Date) {
        guard cost != 0 else { return }
        if let first = entries.first, case .hints(let count) = first.kind,
           Calendar.current.isDate(first.date, inSameDayAs: date) {
            entries[0] = PointsEntry(id: first.id, date: date,
                                     kind: .hints(count: count + 1),
                                     amount: first.amount - cost)
        } else {
            push(PointsEntry(date: date, kind: .hints(count: 1), amount: -cost))
        }
    }

    mutating func addCompensation(_ amount: Int, at date: Date) {
        guard amount != 0 else { return }
        if let first = entries.first, case .compensation(let count) = first.kind,
           Calendar.current.isDate(first.date, inSameDayAs: date) {
            entries[0] = PointsEntry(id: first.id, date: date,
                                     kind: .compensation(count: count + 1),
                                     amount: first.amount + amount)
        } else {
            push(PointsEntry(date: date, kind: .compensation(count: 1), amount: amount))
        }
    }

    private mutating func push(_ entry: PointsEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case version, entries }

    /// A ledger written in another format is dropped, not misread: losing the
    /// history costs nothing (the balance is stored apart), showing wrong lines
    /// would.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        guard version == Self.currentVersion,
              let entries = try? c.decode([PointsEntry].self, forKey: .entries) else {
            self.init()
            return
        }
        self.init(entries: entries)
    }
}
