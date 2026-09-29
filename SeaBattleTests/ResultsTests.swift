//
//  ResultsTests.swift
//  SeaBattleTests
//
//  R2.5 — итоги партии. Проверяется то, что на экране не отличить от
//  правильного: серия, не оборванная промахом, повторный выстрел в точности,
//  строка за исход при поражении, подсказки, потерянные после «Продолжить
//  партию», итог, пришедший через секунду вместо момента выстрела.
//

import Foundation
import Testing
import SwiftUI
@testable import SeaBattle

@MainActor
@Suite("Итоги партии")
struct ResultsTests {

    private let hit = Board.ShotResult.hit(shipID: nil)

    // MARK: Счёт партии

    @Test("Промах обрывает серию, лучшая серия остаётся")
    func aMissBreaksTheStreak() {
        var tally = MatchTally()
        for result in [hit, hit, hit, .miss, hit, hit] { tally.record(result) }
        #expect(tally.shots == 6)
        #expect(tally.hits == 5)
        #expect(tally.bestStreak == 3)
        #expect(tally.streak == 2)
    }

    @Test("Повторный выстрел — выстрел, но не попадание; мимо поля не считается")
    func aRepeatShotCountsAsAShotOnly() {
        var tally = MatchTally()
        tally.record(hit)
        tally.record(.repeated(.hit))
        tally.record(.offBoard)
        #expect(tally.shots == 2)
        #expect(tally.hits == 1)
        #expect(tally.streak == 0)
        #expect(tally.accuracy == 0.5)
    }

    @Test("Без выстрелов точности нет, а не ноль")
    func noShotsNoAccuracy() {
        #expect(MatchTally().accuracy == nil)
    }

    // MARK: Чек

    private func result(won: Bool, level: AppState.DifficultyLevel = .hard,
                        hints: Int = 0, cost: Int = 6) -> MatchResult {
        var tally = MatchTally()
        for _ in 0..<hints { tally.recordHint(cost: cost) }
        return MatchResult(didWin: won, level: level, yourLosses: won ? 2 : 10,
                           foeLosses: won ? 10 : 7, tally: tally, balance: 100)
    }

    @Test("Победа: строка за исход по ставке уровня, подсказки минусом")
    func aWinPaysTheLevelStake() {
        let r = result(won: true, level: .expert, hints: 2, cost: 10)
        #expect(r.lines == [.victory(points: 10), .hints(count: 2, points: 20)])
        #expect(r.net == -10)
    }

    @Test("Поражение: строки за исход нет вовсе (4.9)")
    func aLossHasNoOutcomeLine() {
        #expect(result(won: false).lines.isEmpty)
        #expect(result(won: false, hints: 1, cost: 3).lines == [.hints(count: 1, points: 3)])
    }

    @Test("Число в шапке чека — со знаком и типографским минусом")
    func signedNumbers() {
        #expect(MatchResult.signed(60) == "+60")
        #expect(MatchResult.signed(-5) == "\u{2212}5")
        #expect(MatchResult.signed(0) == "0")
    }

    // MARK: Бой отдаёт итог

    private func match() -> (AppState, BattleController) {
        let appState = AppState()
        appState.soundOn = false
        appState.musicOn = false
        // Общий через `UserDefaults` с `BattleTests`: без явного значения
        // первое касание могло бы поставить прицел вместо выстрела.
        appState.confirmShot = false
        let battle = BattleController(pacing: .instant)
        battle.configure(appState: appState)
        appState.resetData(player: battle.player, enemy: battle.enemy)
        battle.player.shipsRandomArrangement()
        battle.enemy.shipsRandomArrangement()
        appState.gameIsActive = true
        appState.selectedTab = .enemyView
        battle.beginMatch()
        return (appState, battle)
    }

    @Test("Итог ставится в момент последнего выстрела, со счётом и балансом")
    func theLastShotProducesTheResult() throws {
        let (appState, battle) = match()
        let cells = battle.enemy.ships.flatMap { $0.coordinates.map(Coordinate.init) }
        for cell in cells.dropLast() { battle.tap(cell) }
        #expect(battle.result == nil)

        battle.tap(cells.last!)
        let result = try #require(battle.result)
        #expect(appState.gameIsOver)
        #expect(result.didWin == true)
        #expect(result.foeLosses == FleetLayout.shipCount)
        #expect(result.yourLosses == 0)
        #expect(result.tally.shots == cells.count)
        #expect(result.tally.bestStreak == cells.count)
        // Баланс — после начисления победы.
        #expect(result.balance == ProgressStore.shared.points)
        #expect(result.lines.first == .victory(points: appState.difficultyLevel.pointsValue))
    }

    @Test("Подсказка попадает в счёт партии и в чек")
    func aHintIsCharged() {
        let (_, battle) = match()
        ProgressStore.shared.addPoints(battle.hintCost)
        #expect(battle.requestHint())
        #expect(battle.tally.hintsUsed == 1)
        #expect(battle.tally.hintPointsSpent == battle.hintCost)
    }

    @Test("Новая партия снимает итог; продолженная приносит свой счёт")
    func beginMatchResetsOrRestores() {
        let (_, battle) = match()
        for cell in battle.enemy.ships.flatMap({ $0.coordinates.map(Coordinate.init) }) {
            battle.tap(cell)
        }
        #expect(battle.result != nil)

        var saved = MatchTally()
        saved.record(hit)
        saved.recordHint(cost: 3)
        battle.beginMatch(tally: saved)
        #expect(battle.result == nil)
        #expect(battle.tally == saved)

        battle.beginMatch()
        #expect(battle.tally == MatchTally())
    }

    // MARK: Сохранение

    @Test("Счёт партии переживает сохранение, а старое сохранение без него читается")
    func theTallySurvivesTheSave() throws {
        let (appState, battle) = match()
        battle.tap(Coordinate(battle.enemy.ships[0].coordinates[0]))
        let data = try JSONEncoder().encode(battle.snapshot(of: appState))
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        #expect(decoded.tally == battle.tally)
        #expect(decoded.tally?.shots == 1)

        // Сохранение до R2.5: ключа нет вовсе.
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "tally")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let old = try JSONDecoder().decode(GameSnapshot.self, from: legacy)
        #expect(old.tally == nil)
        #expect(old.schemaVersion == GameSnapshot.currentSchemaVersion)
    }

    // MARK: Рамка результата

    @Test("Рамка результата в цвете исхода: свечение вместо тени")
    func theOutcomeFrameTakesTheRoleColor() {
        #expect(GlassHighlight.outcome(.you).stroke == .roleYou)
        #expect(GlassHighlight.outcome(.foe).stroke == .roleFoe)
        #expect(GlassHighlight.outcome(.foe).isLit)
        // Пара мягких цветов ролей и свечение 0 0 24 (спека 4.9, раунд 6).
        #expect(GlassHighlight.outcome(.you).glow == .roleYouSoft)
        #expect(GlassHighlight.outcome(.foe).glow == .roleFoeSoft)
        #expect(GlassHighlight.outcome(.foe).glowRadius == 12)
        #expect(!GlassHighlight.outcome(.you).isSelected)
        #expect(GlassHighlight.none.stroke == nil)
        #expect(GlassHighlight.selected.stroke == .roleYou)
    }
}
