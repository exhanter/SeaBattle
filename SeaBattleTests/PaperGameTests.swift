//
//  PaperGameTests.swift
//  SeaBattleTests
//
//  R3.1 — игра на бумаге. Проверяется то, что на экране не отличить от
//  правильного до конца партии: ход, ушедший не тому, «Убит», закрасивший
//  не всю связку, откат дальше одного хода, победа без флота соперника.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
@Suite("Игра на бумаге")
struct PaperGameTests {

    /// Своё поле — эталонная расстановка: клетки известны, (10, 10) — вода.
    private func game(revealsRing: Bool = false) -> PaperGame {
        PaperGame(fleet: FleetLayout.canonicalLayout(), revealsRing: revealsRing)
    }

    private func c(_ row: Int, _ column: Int) -> Coordinate {
        Coordinate(row: row, column: column)
    }

    private func call(_ game: inout PaperGame, _ cell: Coordinate, _ answer: PaperAnswer) {
        let r1 = game.aim(at: cell)
        #expect(r1)
        game.answer(answer)
    }

    // MARK: Такт 1

    @Test("Пока нет ответа, прицел переносится свободно")
    func theAimMovesUntilAnswered() {
        var g = game()
        let r2 = g.aim(at: c(4, 5))
        #expect(r2)
        let r3 = g.aim(at: c(7, 2))
        #expect(r3)
        #expect(g.aim == c(7, 2))
        #expect(g.foe[c(4, 5)] == .water)
        #expect(g.moves == 0)
    }

    @Test("Без прицела ответа нет; на отмеченную клетку прицел не встаёт")
    func answersNeedAnAimOnAFreshCell() {
        var g = game()
        let r4 = g.answer(.miss)
        #expect(r4 == nil)
        call(&g, c(1, 1), .hit)
        let r5 = g.aim(at: c(1, 1))
        #expect(!r5)
        #expect(g.aim == nil)
    }

    @Test("«Мимо» отдаёт ход сопернику, «Ранен» оставляет вам")
    func theAnswerDecidesTheTurn() {
        var g = game()
        call(&g, c(2, 2), .hit)
        #expect(g.turn == .you)
        #expect(g.foe[c(2, 2)] == .hit)
        #expect(g.last == PaperOutcome(field: .foe, coordinate: c(2, 2), call: .hit))

        call(&g, c(2, 3), .miss)
        #expect(g.turn == .foe)
        #expect(g.aim == nil)
        #expect(!g.acceptsYourShot)
        let r6 = g.aim(at: c(8, 8))
        #expect(!r6)
    }

    @Test("«Убит» закрашивает всю связку попаданий у последнего выстрела")
    func sunkPaintsTheWholeRun() {
        var g = game()
        call(&g, c(4, 4), .hit)
        call(&g, c(4, 5), .hit)
        call(&g, c(8, 8), .hit)            // другой, ещё живой корабль
        call(&g, c(4, 6), .sunk)
        for column in 4...6 { #expect(g.foe[c(4, column)] == .sunk) }
        #expect(g.foe[c(8, 8)] == .hit)
        #expect(g.foe.sunkShipCount == 1)
        #expect(g.turn == .you)
        #expect(g.foe[c(3, 4)] == .water)  // обводка выключена
    }

    @Test("Обводка промахами — по настройке, вокруг всей связки")
    func theRingIsRevealedWhenAsked() {
        var g = game(revealsRing: true)
        call(&g, c(1, 1), .hit)
        call(&g, c(1, 2), .sunk)
        for cell in [c(2, 1), c(2, 2), c(2, 3), c(1, 3)] { #expect(g.foe[cell] == .miss) }
        #expect(g.foe[c(3, 3)] == .water)
    }

    // MARK: Такт 2

    @Test("Ход соперника считается по своему флоту; попадание оставляет ход ему")
    func theOpponentsShotIsResolvedByTheCore() {
        var g = game()
        call(&g, c(9, 9), .miss)
        let hit = g.opponentShot(at: c(1, 1))
        #expect(hit?.call == .hit)
        #expect(g.own[c(1, 1)] == .hit)
        #expect(g.turn == .foe)

        let miss = g.opponentShot(at: c(10, 10))
        #expect(miss == PaperOutcome(field: .you, coordinate: c(10, 10), call: .miss))
        #expect(g.own[c(10, 10)] == .miss)
        #expect(g.turn == .you)
        let r7 = g.opponentShot(at: c(9, 1))
        #expect(r7 == nil)
    }

    @Test("Однопалубник топится с первого выстрела; повторный — ход вам")
    func sinkingAndRepeatsOnYourBoard() {
        var g = game()
        let r8 = g.opponentShot(at: c(5, 4))
        #expect(r8?.call == .sunk)
        #expect(g.own.sunkShipCount == 1)
        #expect(g.turn == .foe)
        let r9 = g.opponentShot(at: c(5, 4))
        #expect(r9?.call == .repeatHit)
        #expect(g.turn == .you)
    }

    @Test("До первого хода первым может стрелять любой")
    func eitherSideMayOpen() {
        var g = game()
        #expect(g.acceptsYourShot && g.acceptsOpponentShot)
        g.aim(at: c(3, 3))
        g.opponentShot(at: c(10, 10))
        // Соперник начал: названная клетка сброшена, ход — ваш после его промаха.
        #expect(g.aim == nil)
        #expect(g.turn == .you)
    }

    // MARK: Откат

    @Test("Отмена — ровно один ход, прицел возвращается на место")
    func undoGoesBackExactlyOneMove() {
        var g = game()
        call(&g, c(6, 6), .hit)
        call(&g, c(6, 7), .miss)
        #expect(g.canUndo)
        let r10 = g.undo()
        #expect(r10)
        #expect(g.foe[c(6, 7)] == .water)
        #expect(g.aim == c(6, 7))
        #expect(g.turn == .you)
        #expect(g.foe[c(6, 6)] == .hit)
        #expect(g.tally.shots == 1)
        // Дальше история не откатывается, кнопка гаснет до следующего хода.
        #expect(!g.canUndo)
        let r11 = g.undo()
        #expect(!r11)
        #expect(g.foe[c(6, 6)] == .hit)

        g.answer(.hit)
        #expect(g.canUndo)
    }

    @Test("Отмена хода соперника возвращает клетку и ход")
    func undoTheOpponentsShot() {
        var g = game()
        g.opponentShot(at: c(1, 1))
        let r12 = g.undo()
        #expect(r12)
        #expect(g.own[c(1, 1)] == .ship)
        #expect(g.turn == nil)
        #expect(g.moves == 0)
    }

    // MARK: Конец партии

    /// Десять однопалубных «убит» в клетках, которые не соприкасаются.
    private func sinkTen(_ g: inout PaperGame) {
        for index in 0..<10 {
            call(&g, c(1 + (index / 5) * 2, 1 + (index % 5) * 2), .sunk)
        }
    }

    @Test("Победа — десять потопленных связок; после неё ходов и отката нет")
    func tenSunkRunsWin() {
        var g = game()
        sinkTen(&g)
        #expect(g.winner == .you)
        #expect(!g.acceptsYourShot && !g.acceptsOpponentShot)
        #expect(!g.canUndo)
        #expect(g.tally.hits == 10)
    }

    @Test("Поражение — соперник потопил весь свой флот")
    func losingTheFleetLoses() {
        var g = game()
        for ship in FleetLayout.canonicalLayout() {
            for cell in ship.cells { g.opponentShot(at: cell) }
        }
        #expect(g.winner == .foe)
    }

    @Test("Сохранение переживает партию вместе с откатом")
    func theGameSurvivesEncoding() throws {
        var g = game(revealsRing: true)
        call(&g, c(4, 4), .hit)
        g.aim(at: c(4, 5))
        let data = try JSONEncoder().encode(PaperSave(game: g))
        let back = try JSONDecoder().decode(PaperSave.self, from: data)
        #expect(back.game == g)
        #expect(back.schemaVersion == PaperSave.currentSchemaVersion)
    }

    // MARK: Контроллер

    @Test("После «Мимо» экран сам уходит на своё поле, после промаха соперника — назад")
    func theFieldFollowsTheTurn() async {
        let match = PaperMatch(game: game(), pacing: .instant, persists: false)
        match.soundOn = false
        #expect(match.shownField == .foe)
        match.tapFoe(c(9, 9))
        match.answer(.miss)
        #expect(match.event(on: .foe)?.outcome == .miss)
        await match.waitForSwitch()
        #expect(match.shownField == .you)

        match.tapOwn(c(10, 10))
        await match.waitForSwitch()
        #expect(match.shownField == .foe)
        #expect(match.event(on: .you)?.target == c(10, 10))
    }

    @Test("Отмена гасит событие и возвращает поле того, кто стрелял")
    func undoResetsTheScreen() async {
        let match = PaperMatch(game: game(), pacing: .instant, persists: false)
        match.soundOn = false
        match.tapFoe(c(9, 9))
        match.answer(.miss)
        await match.waitForSwitch()
        match.undo()
        #expect(match.lastEvent == nil)
        #expect(match.shownField == .foe)
        #expect(match.game.aim == c(9, 9))
    }

    @Test("Итог: графа «игра на бумаге», баллов ноль, строк чека нет")
    func theResultPaysNothing() {
        var g = game()
        for index in 0..<9 {
            call(&g, c(1 + (index / 5) * 2, 1 + (index % 5) * 2), .sunk)
        }
        let match = PaperMatch(game: g, pacing: .instant, persists: false)
        match.soundOn = false
        match.tapFoe(c(3, 9))
        match.answer(.sunk)
        let result = match.result
        #expect(result?.didWin == true)
        #expect(result?.key == .paper)
        #expect(result?.level == nil)
        #expect(result?.foeLosses == 10)
        #expect(result?.lines.isEmpty == true)
        #expect(result?.net == 0)
    }

    // MARK: «Продолжить партию»

    @Test("Игра на бумаге — своя незакрытая партия в «Продолжить»")
    func paperIsAContinueTarget() {
        #expect(ContinueTarget.resolve(isPlaying: false, hasVsComputer: false,
                                       hasHotSeat: false, hasPaper: true) == .paper)
        #expect(ContinueTarget.resolve(isPlaying: false, hasVsComputer: true,
                                       hasHotSeat: false, hasPaper: true) == .ask)
        // Партия против компьютера в памяти не прячет партию на бумаге.
        #expect(ContinueTarget.resolve(isPlaying: true, hasVsComputer: false,
                                       hasHotSeat: false, hasPaper: true) == .ask)
        #expect(ContinueTarget.resolve(isPlaying: true, hasVsComputer: true,
                                       hasHotSeat: false) == .resume)
    }
}
