//
//  BattleTests.swift
//  SeaBattleTests
//
//  R2.3 — бой против компьютера. Проверяется поведение между правилами и
//  экраном: кто стреляет, когда экран уходит на своё поле и возвращается,
//  что пишет лента, как работает прицел. Всё это молчит при поломке — сборка
//  остаётся зелёной, а партия играется не так.
//

import Testing
import SwiftUI
@testable import SeaBattle

@MainActor
@Suite("Бой против компьютера")
struct BattleTests {

    private func match(confirm: Bool = false) -> (AppState, BattleController) {
        let appState = AppState()
        appState.soundOn = false
        appState.confirmShot = confirm
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

    private func shipCell(_ data: PlayerData) -> Coordinate {
        Coordinate(data.ships[0].coordinates[0])
    }

    private func waterCell(_ data: PlayerData) -> Coordinate {
        Board.allCoordinates.first { data.coreBoard[$0] == .water }!
    }

    // MARK: Ход

    @Test("Попадание оставляет ход игроку, компьютер не стреляет")
    func aHitKeepsTheTurn() {
        let (appState, battle) = match()
        battle.tap(shipCell(battle.enemy))

        #expect(!appState.enemysTurn)
        #expect(!battle.isOpponentThinking)
        #expect(battle.shownField == .foe)
    }

    @Test("После промаха компьютер доигрывает ход, лента пишет его выстрелы, экран возвращается")
    func aMissHandsTheTurnOver() async {
        let (appState, battle) = match()
        battle.tap(waterCell(battle.enemy))
        #expect(appState.enemysTurn)
        #expect(battle.isOpponentThinking)

        await battle.waitForOpponent()

        // Компьютер стреляет, пока попадает, поэтому в ленте минимум один
        // выстрел, и промахом кончается ровно последний.
        #expect(!battle.incoming.isEmpty)
        #expect(battle.incoming.dropLast().allSatisfy { $0.outcome.isDamage })
        if appState.gameIsActive {
            #expect(battle.incoming.last?.outcome == .miss)
            #expect(!appState.enemysTurn)
            #expect(battle.shownField == .foe)
        }
        #expect(!battle.isOpponentThinking)
        // Номера капсул не повторяются — иначе повторный выстрел слился бы.
        #expect(Set(battle.incoming.map(\.id)).count == battle.incoming.count)
    }

    @Test("Повторный выстрел ничего не меняет на поле и отдаёт ход")
    func aRepeatShotPassesTheTurn() async {
        let (appState, battle) = match()
        let cell = shipCell(battle.enemy)
        battle.tap(cell)
        let before = battle.enemy.coreBoard

        battle.tap(cell)
        #expect(battle.enemy.coreBoard[cell] == before[cell])
        #expect(appState.enemysTurn)
        await battle.waitForOpponent()
    }

    @Test("Выход в меню не возвращает игрока на поле, когда компьютер доиграет")
    func theOpponentDoesNotPullThePlayerBackFromTheMenu() {
        let (appState, battle) = match()
        appState.selectedTab = .menu
        battle.show(.foe)
        #expect(appState.selectedTab == .menu)
    }

    @Test("Новая партия обрывает ход компьютера и чистит ленту")
    func aNewMatchCancelsTheOpponent() {
        let (_, battle) = match()
        battle.tap(waterCell(battle.enemy))
        #expect(battle.isOpponentThinking)
        battle.beginMatch()
        #expect(!battle.isOpponentThinking)
        #expect(battle.incoming.isEmpty)
        #expect(battle.aim == nil)
    }

    // MARK: Подтверждение выстрела

    @Test("С подтверждением первое касание ставит прицел, второе стреляет")
    func confirmationAimsThenFires() {
        let (_, battle) = match(confirm: true)
        let cell = shipCell(battle.enemy)
        let other = waterCell(battle.enemy)

        battle.tap(cell)
        #expect(battle.aim == cell)
        #expect(battle.enemy.coreBoard[cell] == .ship)

        // Касание другой клетки переносит прицел, а не стреляет.
        battle.tap(other)
        #expect(battle.aim == other)
        #expect(battle.enemy.coreBoard[other] == .water)

        battle.tap(cell)
        battle.tap(cell)
        #expect(battle.aim == nil)
        #expect(battle.enemy.coreBoard[cell].holdsKnownShip)
    }

    @Test("Без подтверждения стреляет первое касание")
    func withoutConfirmationOneTapFires() {
        let (_, battle) = match()
        let cell = shipCell(battle.enemy)
        battle.tap(cell)
        #expect(battle.aim == nil)
        #expect(battle.enemy.coreBoard[cell].holdsKnownShip)
    }

    @Test("Подтверждение выстрела по умолчанию выключено")
    func confirmationIsOffByDefault() {
        UserDefaults.standard.removeObject(forKey: "confirmShot")
        #expect(!AppState().confirmShot)
    }

    @Test("На ходе соперника касание не стреляет и подсказка погашена")
    func nothingFiresOnTheOpponentsTurn() {
        let (appState, battle) = match()
        appState.enemysTurn = true
        let cell = shipCell(battle.enemy)
        battle.tap(cell)
        #expect(battle.enemy.coreBoard[cell] == .ship)
        #expect(!battle.canUseHint)
    }

    // MARK: Лента

    @Test("Лента различает повторное попадание и повторный выстрел")
    func theFeedNamesRepeatShots() {
        #expect(FeedOutcome(.repeated(.hit)) == .repeatHit)
        #expect(FeedOutcome(.repeated(.sunk)) == .repeatHit)
        #expect(FeedOutcome(.repeated(.miss)) == .repeatMiss)
        #expect(FeedOutcome(.miss) == .miss)
        #expect(FeedOutcome(.offBoard) == nil)
        #expect(!FeedOutcome.repeatHit.isDamage)
    }

    @Test("Клетка в ленте названа буквой языка интерфейса")
    func theFeedUsesTheBoardAlphabet() {
        let cell = Coordinate(row: 3, column: 7)
        #expect(ShotChip.label(cell, alphabet: .cyrillic) == "Ж3")
        #expect(ShotChip.label(cell, alphabet: .latin) == "G3")
        #expect(ShotChip.label(Coordinate(row: 10, column: 10), alphabet: .cyrillic) == "К10")
    }

    // MARK: Числа компонентов

    @Test("Переключатель полей: сегмент 44 pt, обойма 3 pt")
    func theFieldSwitchIsTallEnough() {
        #expect(Geometry.Segment.height == Geometry.Hit.minTarget)
        #expect(Geometry.Segment.trackInset == 3)
    }

    @Test("Панель счёта и подсказка по кадрам 393 и 375")
    func battleMetricsFollowTheFrames() {
        #expect(BattleMetrics.forSize(.regular) == .regular)
        #expect(BattleMetrics.forSize(.compact) == .compact)
        #expect(BattleMetrics.regular.scoreRadius == Geometry.Radius.panel)
        #expect(BattleMetrics.regular.sideNumber == 20)
        #expect(BattleMetrics.compact.sideNumber == 17)
        #expect(BattleMetrics.regular.hintIcon == 21)
        #expect(BattleMetrics.compact.hintIcon == 19)
        #expect(BattleMetrics.fleetDots == 10)
    }
}
