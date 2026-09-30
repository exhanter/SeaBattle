//
//  DuelGameTests.swift
//  SeaBattleTests
//
//  R3.2 — вдвоём на устройстве. Проверяется то, что нажатиями не поймать:
//  поля, открытые без кода, ход, ушедший не тому, лента не того игрока,
//  код, который пускает после продолжения из меню, серия, потерянная на
//  «Ещё партии».
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
@Suite("Вдвоём на устройстве")
struct DuelGameTests {

    private let players = [DuelPlayer(name: "Аня", glyph: "sailboat.fill", colorIndex: 0),
                           DuelPlayer(name: "Борис", glyph: "helm", colorIndex: 8)]

    private func c(_ row: Int, _ column: Int) -> Coordinate {
        Coordinate(row: row, column: column)
    }

    private func game(locks: Bool = false, first: Int = 0) -> DuelGame {
        DuelGame(players: players, locksWithCode: locks, revealsRing: false,
                 firstMove: .player(first), firstShooter: first)
    }

    /// Обе расстановки — эталонные: (1,1)–(1,4) четырёхпалубный, (10,10) вода.
    private func battle(locks: Bool = false, first: Int = 0) -> DuelGame {
        var g = game(locks: locks, first: first)
        if locks { g.open(with: "1111") }
        g.finishArrangement(FleetLayout.canonicalLayout())
        g.open(with: locks ? "2222" : nil)
        g.finishArrangement(FleetLayout.canonicalLayout())
        g.open(with: locks ? (first == 0 ? "1111" : "2222") : nil)
        return g
    }

    // MARK: Передача

    @Test("Без кода первый игрок расставляет сразу, второму — слой передачи")
    func placementHandsOverOnce() {
        var g = game()
        #expect(g.handoff == nil)
        #expect(g.stage == .arranging(0))
        g.finishArrangement(FleetLayout.canonicalLayout())
        #expect(g.stage == .arranging(1))
        #expect(g.handoff == 1)
        #expect(g.codeStep == .none)
    }

    @Test("Начало боя объявляется слоем, даже если устройство уже у стреляющего")
    func battleStartIsAnnounced() {
        var g = game(first: 1)
        g.finishArrangement(FleetLayout.canonicalLayout())
        g.open()
        g.finishArrangement(FleetLayout.canonicalLayout())
        #expect(g.isBattle)
        #expect(g.handoff == 1)
        #expect(g.turn == 1)
        // Устройство не меняло рук — кода не спрашивают.
        #expect(g.codeStep == .none)
    }

    @Test("Пока слой не открыт, выстрела нет")
    func noShotUnderTheLayer() {
        var g = game()
        g.finishArrangement(FleetLayout.canonicalLayout())
        g.open()
        g.finishArrangement(FleetLayout.canonicalLayout())
        let r1 = g.fire(at: c(1, 1))
        #expect(r1 == nil)
        g.open()
        let r2 = g.fire(at: c(1, 1))
        #expect(r2 != nil)
    }

    @Test("Попадание оставляет ход, промах отдаёт и устройство, и ход")
    func missPassesTheDevice() {
        var g = battle()
        g.fire(at: c(1, 1))
        #expect(g.attacker == 0)
        #expect(g.handoff == nil)
        g.fire(at: c(10, 10))
        #expect(g.attacker == 1)
        #expect(g.handoff == 1)
        #expect(g.turn == 2)
        #expect(!g.acceptsShot)
    }

    @Test("Повторный выстрел тоже отдаёт ход")
    func repeatedShotPassesTheTurn() {
        var g = battle()
        g.fire(at: c(1, 1))
        g.fire(at: c(1, 1))
        #expect(g.attacker == 1)
    }

    // MARK: Лента «По вам»

    @Test("Лента — выстрелы соперника за его последний ход, у того, по кому стреляли")
    func incomingBelongsToTheTarget() {
        var g = battle()
        g.fire(at: c(1, 1))
        g.fire(at: c(10, 10))       // Аня: ранен, мимо
        #expect(g.incoming[1].map(\.coordinate) == [c(1, 1), c(10, 10)])
        #expect(g.incoming[0].isEmpty)
        g.open()
        g.fire(at: c(9, 9))         // Борис: мимо
        #expect(g.incoming[0].map(\.coordinate) == [c(9, 9)])
        g.open()
        // У Бориса лента живёт до нового хода Ани — и новый ход её начинает заново.
        g.fire(at: c(8, 8))
        #expect(g.incoming[1].map(\.coordinate) == [c(8, 8)])
    }

    @Test("Экран рисуется глазами держателя: чужой флот скрыт")
    func theViewerSeesOnlyTheirOwnFleet() {
        let g = battle()
        let match = DuelMatch(game: g, pacing: .instant, persists: false)
        #expect(match.viewer == 0)
        #expect(match.board(.you)[c(1, 1)] == .ship)
        #expect(match.board(.foe)[c(1, 1)] == .water)
    }

    // MARK: Код

    @Test("Код придумывают при первой передаче и спрашивают при каждой следующей")
    func theCodeIsCreatedThenAsked() {
        var g = game(locks: true)
        #expect(g.handoff == 0)
        #expect(g.codeStep == .create)
        let short = g.open(with: "12")
        #expect(!short)
        let created = g.open(with: "1111")
        #expect(created)
        g.finishArrangement(FleetLayout.canonicalLayout())
        #expect(g.codeStep == .create)
        g.open(with: "2222")
        g.finishArrangement(FleetLayout.canonicalLayout())
        #expect(g.codeStep == .enter)
        let wrong = g.open(with: "2222")
        #expect(!wrong)
        #expect(g.handoff == 0)
        let right = g.open(with: "1111")
        #expect(right)
    }

    @Test("После выхода в меню код спрашивают и у того, кто держал устройство")
    func relockForgetsTheHolder() {
        var g = battle(locks: true)
        #expect(g.acceptsShot)
        g.relock()
        #expect(g.handoff == 0)
        #expect(g.codeStep == .enter)
        #expect(!g.acceptsShot)
        let open = g.open(with: "1111")
        #expect(open)
        #expect(g.acceptsShot)
    }

    @Test("Код не хранится открытым текстом")
    func theCodeIsHashed() throws {
        var g = game(locks: true)
        g.open(with: "4321")
        let data = try JSONEncoder().encode(g)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("4321"))
        let back = try JSONDecoder().decode(DuelGame.self, from: data)
        #expect(back == g)
    }

    // MARK: Конец и серия

    private func sinkEverything(_ g: inout DuelGame) {
        for ship in FleetLayout.canonicalLayout() {
            for cell in ship.cells { g.fire(at: cell) }
        }
    }

    @Test("Победа — у держателя, счёт серии растёт, «Ещё партия» его сохраняет")
    func theSeriesSurvivesARematch() {
        var g = battle(locks: true)
        sinkEverything(&g)
        #expect(g.winner == 0)
        #expect(g.series == [1, 0])
        let next = g.rematch()
        #expect(next.series == [1, 0])
        #expect(next.stage == .arranging(0))
        #expect(next.codes == g.codes)
        // Устройство у Ани, код у неё есть — расставлять можно сразу.
        #expect(next.handoff == nil)
    }

    @Test("Итог — счёт серии без баллов, статистика не пишется")
    func theResultCarriesTheSeries() {
        var g = battle()
        let match = DuelMatch(game: g, pacing: .instant, persists: false)
        match.soundOn = false
        for ship in FleetLayout.canonicalLayout() {
            for cell in ship.cells { match.tap(cell) }
        }
        let result = match.result
        #expect(result?.duel?.winner == 0)
        #expect(result?.duel?.series == [1, 0])
        #expect(result?.key == .hotSeat)
        #expect(result?.lines.isEmpty == true)
        sinkEverything(&g)
        #expect(g.isOver)
    }

    @Test("Промах показывает слой только после паузы")
    func theLayerWaitsForTheMiss() async {
        let match = DuelMatch(game: battle(), pacing: DuelPacing(handOver: .milliseconds(50)),
                              persists: false)
        match.soundOn = false
        match.tap(c(10, 10))
        #expect(!match.showsHandoff)
        #expect(match.viewer == 0)
        await match.waitForHandoff()
        #expect(match.showsHandoff)
        match.open()
        #expect(match.viewer == 1)
        #expect(match.shownField == .foe)
        #expect(match.lastEvent == nil)
    }

    // MARK: Настройка

    @Test("Пустые имена — «Игрок 1» и «Игрок 2», одинаковые не пускают")
    func setupNames() {
        var setup = DuelSetup()
        #expect(setup.namesDiffer)
        #expect(setup.resolvedPlayers.map(\.name).allSatisfy { !$0.isEmpty })
        setup.players[0].name = "Аня"
        setup.players[1].name = " аня "
        #expect(!setup.namesDiffer)
    }

    @Test("Жребий бросается и выбирает обоих")
    func theCoinTossPicksBoth() {
        var generator = SystemRandomNumberGenerator()
        let picks = Set((0..<64).map { _ in DuelFirstMove.coinToss.resolve(using: &generator) })
        #expect(picks == [0, 1])
        #expect(DuelFirstMove.player(1).resolve(using: &generator) == 1)
    }

    @Test("Выбранный первым игрок стреляет первым")
    func theChosenPlayerStarts() {
        let g = battle(first: 1)
        #expect(g.attacker == 1)
        #expect(g.viewer == 1)
    }
}
