//
//  AchievementTests.swift
//  SeaBattleTests
//
//  The seven achievements (customer 03.11): what earns each grade, what does
//  not count, and that grades only go up.
//

import Foundation
import Testing
@testable import SeaBattle

struct AchievementTests {

    private func win(_ level: AppState.DifficultyLevel, shots: Int = 60, streak: Int = 3,
                     lost: Int = 3) -> MatchFacts {
        MatchFacts(key: .computer(level), didWin: true, shots: shots, bestStreak: streak, shipsLost: lost)
    }

    private func loss(_ level: AppState.DifficultyLevel, streak: Int = 3) -> MatchFacts {
        MatchFacts(key: .computer(level), didWin: false, shots: nil, bestStreak: streak, shipsLost: 10)
    }

    @Test("Sharp Volley: 40 / 35 / 30 shots, Medium and up, not against people")
    func sharpshooter() {
        var book = AchievementBook()
        let onEasy = book.record(win(.easy, shots: 25))
        #expect(onEasy.isEmpty, "Easy does not count")
        let bronze = book.record(win(.medium, shots: 40))
        #expect(bronze.contains(EarnedMedal(achievement: .sharpshooter, grade: .bronze)))
        _ = book.record(win(.hard, shots: 29))
        #expect(book.grade(.sharpshooter) == .gold)
        // Never goes down, and the same grade is not earned twice.
        let again = book.record(win(.hard, shots: 39))
        #expect(!again.contains { $0.achievement == .sharpshooter })
        #expect(book.grade(.sharpshooter) == .gold)

        var online = AchievementBook()
        _ = online.record(MatchFacts(key: .online, didWin: true, shots: 25, bestStreak: 20, shipsLost: 0))
        #expect(online.grade(.sharpshooter) == nil)
        #expect(online.grade(.barrage) == nil)
        #expect(online.grade(.duelist) == nil, "one win is not ten")
    }

    @Test("Not a Scratch: the grade is the level")
    func unscathed() {
        var book = AchievementBook()
        _ = book.record(win(.easy, lost: 0))
        #expect(book.grade(.unscathed) == nil)
        _ = book.record(win(.hard, lost: 0))
        #expect(book.grade(.unscathed) == .silver)
        _ = book.record(win(.medium, lost: 0))
        #expect(book.grade(.unscathed) == .silver, "a lower level does not lower the grade")
    }

    @Test("Winning Streak: ten in a row per level; a loss there resets only that level")
    func streak() {
        var book = AchievementBook()
        for _ in 0..<9 { _ = book.record(win(.hard)) }
        // Other levels do not break the run.
        _ = book.record(loss(.medium))
        _ = book.record(win(.expert))
        #expect(book.grade(.streak) == nil)
        _ = book.record(win(.hard))
        #expect(book.grade(.streak) == .silver)

        var broken = AchievementBook()
        for _ in 0..<9 { _ = broken.record(win(.medium)) }
        _ = broken.record(loss(.medium))
        _ = broken.record(win(.medium))
        #expect(broken.grade(.streak) == nil)
    }

    @Test("Hail of Fire: 8 / 10 / 15 hits in a row, win or lose, Medium and up")
    func barrage() {
        var book = AchievementBook()
        _ = book.record(win(.easy, streak: 20))
        #expect(book.grade(.barrage) == nil)
        _ = book.record(loss(.medium, streak: 10))
        #expect(book.grade(.barrage) == .silver)
    }

    @Test("Counters: Expert's Bane, Duellist and Sea Wolf count wins")
    func counters() {
        var book = AchievementBook()
        for _ in 0..<100 { _ = book.record(win(.expert)) }
        #expect(book.grade(.expertSlayer) == .bronze)
        #expect(book.count(.seaWolf) == 100)
        for _ in 0..<10 {
            _ = book.record(MatchFacts(key: .nearby, didWin: true, shots: nil, bestStreak: 2, shipsLost: 5))
        }
        #expect(book.grade(.duelist) == .bronze)
        #expect(book.count(.seaWolf) == 110)
        #expect(book.nextGrade(.duelist) == .silver)
    }

    @Test("Secret achievements stay hidden until earned; counters show from the start")
    func visibility() {
        var book = AchievementBook()
        #expect(!book.isShown(.sharpshooter))
        #expect(!book.isShown(.unscathed))
        #expect(!book.isShown(.barrage))
        #expect(book.isShown(.streak) && book.isShown(.seaWolf))
        _ = book.record(win(.medium, shots: 38))
        #expect(book.isShown(.sharpshooter))
    }

    @Test("Medals go to the dossier most valuable first, and survive saving")
    func medalsAndSaving() throws {
        var stats = PlayerStats()
        _ = stats.achievements.record(win(.medium, shots: 40))
        _ = stats.achievements.record(win(.expert, lost: 0))
        #expect(stats.achievements.medals.first == "unscathed_gold")
        #expect(PlayerDossier(stats).medals == stats.achievements.medals)

        let back = try JSONDecoder().decode(PlayerStats.self, from: JSONEncoder().encode(stats))
        #expect(back.achievements == stats.achievements)
        #expect(EarnedMedal(medal: "sharpshooter_bronze") == EarnedMedal(achievement: .sharpshooter, grade: .bronze))
    }
}
