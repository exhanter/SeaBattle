//
//  WalletTests.swift
//  SeaBattleTests
//
//  R4.1: the points history, the summary the statistics screen shows and the
//  reset by choice. Checked on `PlayerStats` itself, not on `ProgressStore`:
//  the store writes to the real defaults of the test host.
//

import Testing
import Foundation
@testable import SeaBattle

@Suite("Кошелёк и история баллов")
struct WalletTests {

    private let morning = Date(timeIntervalSince1970: 1_790_000_000)
    private var tomorrow: Date { morning.addingTimeInterval(86_400) }

    private func paid(_ stats: inout PlayerStats, _ cost: Int, _ date: Date) -> Bool {
        stats.spendOnHint(cost, at: date)
    }

    @Test("Победа пишет строку с суммой, бумага — нет")
    func aWinLeavesAnEntry() {
        var stats = PlayerStats()
        stats.recordWin(.computer(.hard), at: morning)
        stats.recordWin(.paper, at: morning)

        let reward = AppState.DifficultyLevel.hard.pointsValue
        #expect(stats.points == reward)
        #expect(stats.ledger.entries.count == 1, "партия на бумаге платит 0 — и строки нет")
        let entry = stats.ledger.entries[0]
        #expect(entry.amount == reward)
        #expect(entry.winRow == .computer(.hard))
        #expect(stats.record(.paper).wins == 1, "но в статистику бумага пишется")
    }

    @Test("Подсказки подряд за день — одна строка «2 раза»")
    func hintsInARowMerge() {
        var stats = PlayerStats(points: 30)
        #expect(paid(&stats, 6, morning))
        #expect(paid(&stats, 6, morning))
        #expect(stats.ledger.entries.count == 1)
        #expect(stats.ledger.entries[0].kind == .hints(count: 2))
        #expect(stats.ledger.entries[0].amount == -12)

        // Другой день — новая строка.
        #expect(paid(&stats, 6, tomorrow))
        #expect(stats.ledger.entries.count == 2)
        // Между ними победа — тоже новая строка.
        stats.recordWin(.online, at: tomorrow)
        #expect(paid(&stats, 6, tomorrow))
        #expect(stats.ledger.entries.map(\.amount) == [-6, 10, -6, -12])
        #expect(stats.points == 30 - 24 + 10)
    }

    @Test("На подсказку не хватает — ни списания, ни строки")
    func anUnaffordableHintChangesNothing() {
        var stats = PlayerStats(points: 5)
        #expect(paid(&stats, 6, morning) == false)
        #expect(stats.points == 5)
        #expect(stats.ledger.entries.isEmpty)
    }

    @Test("Компенсация за подсказку соперника — начисление в истории")
    func compensationIsAnEntry() {
        var stats = PlayerStats()
        stats.receiveCompensation(10, at: morning)
        stats.receiveCompensation(10, at: morning)
        #expect(stats.points == 20)
        #expect(stats.ledger.entries.map(\.kind) == [.compensation(count: 2)])
    }

    @Test("История ограничена, старое уходит с конца")
    func theLedgerIsCapped() {
        var ledger = PointsLedger()
        for index in 0..<(PointsLedger.capacity + 7) {
            ledger.addWin(.computer(.easy), points: 1, at: morning.addingTimeInterval(Double(index)))
        }
        #expect(ledger.entries.count == PointsLedger.capacity)
        #expect(ledger.entries.first?.date == morning.addingTimeInterval(Double(PointsLedger.capacity + 6)))
        #expect(ledger.recent.count == 5)
    }

    @Test("История переживает запись и чтение вместе со статистикой")
    func theLedgerRoundTrips() throws {
        var stats = PlayerStats()
        stats.recordWin(.nearby, at: morning)
        _ = stats.spendOnHint(3, at: morning)
        let decoded = try JSONDecoder().decode(PlayerStats.self, from: JSONEncoder().encode(stats))
        #expect(decoded == stats)
    }

    @Test("Чужая версия истории отбрасывается, статистика и баланс целы")
    func aForeignLedgerVersionIsDropped() throws {
        let json = """
        {"records":{"online":{"wins":2,"losses":1}},"unattributedLosses":0,"points":20,
         "ledger":{"version":99,"entries":[{"what":"unknown"}]}}
        """
        let stats = try JSONDecoder().decode(PlayerStats.self, from: Data(json.utf8))
        #expect(stats.ledger.entries.isEmpty)
        #expect(stats.points == 20)
        #expect(stats.record(.online) == StatRecord(wins: 2, losses: 1))
    }

    @Test("Запись до R4.1 — без истории, читается")
    func aRecordWithoutLedgerLoads() throws {
        let json = #"{"records":{},"unattributedLosses":3,"points":7}"#
        let stats = try JSONDecoder().decode(PlayerStats.self, from: Data(json.utf8))
        #expect(stats.ledger.entries.isEmpty)
        #expect(stats.points == 7)
    }

    @Test("Ключ строки статистики читается обратно")
    func storageKeysParseBack() {
        for key in StatKey.tracked + [.hotSeat] {
            #expect(StatKey(storageKey: key.storageKey) == key)
        }
        #expect(StatKey(storageKey: "computer") == nil)
        #expect(StatKey(storageKey: "computer.legendary") == nil)
        #expect(StatKey(storageKey: "online.extra") == nil)
    }
}

@Suite("Сводка и сброс статистики")
struct StatsResetTests {

    private var stats: PlayerStats {
        PlayerStats(records: [
            StatKey.computer(.easy).storageKey: StatRecord(wins: 3, losses: 1),
            StatKey.computer(.hard).storageKey: StatRecord(wins: 1, losses: 2),
            StatKey.paper.storageKey: StatRecord(wins: 9, losses: 9),
            StatKey.online.storageKey: StatRecord(wins: 2, losses: 0),
        ], unattributedLosses: 4, points: 50, ledger: PointsLedger(entries: [
            PointsEntry(date: .now, kind: .win(row: "online"), amount: 10)
        ]))
    }

    @Test("Сводка без бумаги, но с потерями до R0.7")
    func theSummaryLeavesThePaperGameOut() {
        let summary = StatsSummary(stats)
        #expect(summary.wins == 3 + 1 + 2)
        #expect(summary.losses == 1 + 2 + 4)
        #expect(summary.isEmpty == false)
        // Одна бумага — для экрана «партий пока нет».
        let paperOnly = PlayerStats(records: [StatKey.paper.storageKey: StatRecord(wins: 1, losses: 0)])
        #expect(StatsSummary(paperOnly).isEmpty)
    }

    @Test("«Общая сводка» отмечает все режимы и снимает их")
    func everythingTicksEveryMode() {
        var selection = StatsReset()
        #expect(selection.isEmpty)
        selection.toggleEverything()
        #expect(selection.isEverything)
        #expect(selection.modes == Set(StatsSummary.shownModes))
        selection.toggle(.online)
        #expect(selection.isEverything == false, "снял режим — сводка уже не вся")
        selection.toggle(.online)
        #expect(selection.isEverything, "отметил все по одному — это та же сводка")
        selection.toggleEverything()
        #expect(selection.isEmpty)
    }

    @Test("Сброс режима стирает только его, баллы и история остаются")
    func resettingAModeKeepsTheRest() {
        var stats = stats
        stats.reset(StatsReset(modes: [.computer]))
        #expect(stats.record(for: .computer) == StatRecord())
        #expect(stats.record(.online) == StatRecord(wins: 2, losses: 0))
        #expect(stats.record(.paper) == StatRecord(wins: 9, losses: 9))
        #expect(stats.unattributedLosses == 4)
        #expect(stats.points == 50)
        #expect(stats.ledger.entries.count == 1)
    }

    @Test("Сброс всего — вместе с бумагой и старыми потерями; баллы остаются")
    func resettingEverythingClearsHiddenRowsToo() {
        var stats = stats
        var selection = StatsReset()
        selection.toggleEverything()
        stats.reset(selection)
        #expect(stats.records.isEmpty)
        #expect(stats.unattributedLosses == 0)
        #expect(StatsSummary(stats).isEmpty)
        #expect(stats.points == 50)
        #expect(stats.ledger.entries.count == 1)
    }
}
