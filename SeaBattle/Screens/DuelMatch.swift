//
//  DuelMatch.swift
//  Sea Battle — ход партии вдвоём на устройстве (R3.2)
//
//  То, что происходит **между** правилами (`DuelGame`) и экраном: расстановка
//  того, чья очередь, прицел при подтверждении выстрела, событие клетки,
//  звук, пауза перед слоем передачи, сохранение, итог.
//
//  Та же роль, что у `PaperMatch` и `BattleController`. Отдельный тип, а не
//  ветка боя: у этой партии нет компьютера, подсказок и баллов, а экран
//  рисуется глазами того, кто держит устройство.
//

import Foundation
import Observation

/// Пауза перед слоем передачи. Параметром: тест проходит партию без
/// ожидания, а игроку нужно успеть увидеть свой промах.
struct DuelPacing: Sendable {
    var handOver: Duration = .seconds(1.2)

    static let live = DuelPacing()
    static let instant = DuelPacing(handOver: .zero)
}

@MainActor
@Observable
final class DuelMatch {

    private(set) var game: DuelGame
    /// Флот того, кто сейчас расставляет. Новый — на каждого игрока.
    var editor = FleetEditor()
    /// Поле на экране. После открытия слоя — всегда поле противника (2.7).
    private(set) var shownField: Side = .foe
    /// Названная клетка при включённом подтверждении выстрела.
    private(set) var aim: Coordinate?
    /// Последнее событие клетки — одно, анимации не копятся (спека 5).
    private(set) var lastEvent: CellEvent?
    private(set) var result: MatchResult?
    /// Слой передачи на экране. Отстаёт от `game.handoff` на паузу после
    /// промаха — игрок должен увидеть, куда попал, прежде чем экран закроется.
    private(set) var showsHandoff: Bool

    @ObservationIgnored var soundOn = true
    @ObservationIgnored var confirmShot = false
    @ObservationIgnored private let pacing: DuelPacing
    /// Тесты не пишут на диск: сохранение одно на приложение.
    @ObservationIgnored private let persists: Bool
    @ObservationIgnored private var nextEventID = 0
    @ObservationIgnored private var handoffTask: Task<Void, Never>?

    init(game: DuelGame, pacing: DuelPacing = .live, persists: Bool = true) {
        self.game = game
        self.pacing = pacing
        self.persists = persists
        self.showsHandoff = game.handoff != nil
    }

    // MARK: Чтение

    /// Чьими глазами нарисован экран.
    var viewer: Int { game.viewer }
    var opponent: Int { 1 - game.viewer }

    func player(_ index: Int) -> DuelPlayer { game.players[index] }

    /// Поле игрока в роли экрана: своё — с флотом, чужое — как его видит
    /// соперник (`opponentView()`), нетронутые корабли приходят водой.
    func board(_ field: Side) -> Board {
        field == .you ? game.boards[viewer] : game.boards[opponent].opponentView()
    }

    /// «По вам» — выстрелы соперника за его последний ход.
    var incoming: [ShotFeedEntry] { game.incoming[viewer] }

    var isViewersTurn: Bool { game.isBattle && game.attacker == viewer && !game.isOver }

    func event(on field: Side) -> CellEvent? {
        lastEvent?.field == field ? lastEvent : nil
    }

    // MARK: Слой передачи

    /// Открыть слой — с кодом, если он нужен. Неверный код — `false`, слой
    /// остаётся. Открытый экран начинается с поля противника и без события:
    /// прошлый выстрел принадлежит другому игроку.
    @discardableResult
    func open(with code: String? = nil) -> Bool {
        guard game.open(with: code) else { return false }
        cancelHandoff()
        showsHandoff = false
        shownField = .foe
        aim = nil
        lastEvent = nil
        editor = FleetEditor()
        save()
        return true
    }

    /// Вышли в меню или продолжили партию из меню: кто держит устройство,
    /// неизвестно — слой встаёт сразу, без паузы.
    func relock() {
        cancelHandoff()
        game.relock()
        showsHandoff = game.handoff != nil
        aim = nil
        save()
    }

    // MARK: Расстановка

    func finishArrangement() {
        guard case .arranging = game.stage else { return }
        game.finishArrangement(editor.ships)
        editor = FleetEditor()
        showsHandoff = game.handoff != nil
        shownField = .foe
        lastEvent = nil
        save()
        if soundOn { AudioService.shared.play(.click) }
    }

    // MARK: Выстрел

    /// Касание поля противника. При подтверждении первое касание ставит
    /// прицел, второе по той же клетке стреляет (как в бою против компьютера).
    func tap(_ coordinate: Coordinate) {
        guard game.acceptsShot, shownField == .foe else { return }
        if confirmShot && aim != coordinate {
            aim = coordinate
            if soundOn { AudioService.shared.play(.click) }
            return
        }
        aim = nil
        fire(at: coordinate)
    }

    private func fire(at coordinate: Coordinate) {
        let target = game.defender
        let before = game.boards[target].opponentView()
        guard let shot = game.fire(at: coordinate) else { return }
        if let event = CellEvent(id: nextEventID, field: .foe, target: coordinate, result: shot,
                                 before: before, after: game.boards[target].opponentView()) {
            lastEvent = event
            nextEventID += 1
        }
        if soundOn { play(shot) }

        if finishIfOver() { return }
        save()
        if game.handoff != nil { scheduleHandoff() }
    }

    private func play(_ result: Board.ShotResult) {
        switch result {
        case .miss, .repeated: AudioService.shared.play(.missed)
        case .hit: AudioService.shared.play(.hit)
        case .sunk: AudioService.shared.play(.sunk)
        case .offBoard: break
        }
    }

    // MARK: Поле на экране

    func show(_ field: Side) {
        shownField = field
        if field == .you { aim = nil }
    }

    // MARK: Итог и серия

    @discardableResult
    private func finishIfOver() -> Bool {
        guard result == nil, let winner = game.winner else { return false }
        let loser = 1 - winner
        // Статистики у режима нет (4.9): только счёт серии, он в самой партии.
        if persists { DuelStore.clear() }
        result = MatchResult(didWin: true, key: .hotSeat,
                             yourLosses: game.boards[winner].sunkShipCount,
                             foeLosses: game.boards[loser].sunkShipCount,
                             tally: game.tallies[winner],
                             balance: ProgressStore.shared.points,
                             duel: DuelSummary(players: game.players, winner: winner,
                                               series: game.series, turns: game.turn))
        return true
    }

    /// «Ещё партия»: те же игроки, коды и счёт серии.
    func playAgain() {
        cancelHandoff()
        game = game.rematch()
        editor = FleetEditor()
        result = nil
        lastEvent = nil
        aim = nil
        shownField = .foe
        showsHandoff = game.handoff != nil
        save()
    }

    // MARK: Пауза и сохранение

    private func scheduleHandoff() {
        cancelHandoff()
        handoffTask = Task { @MainActor [weak self, pacing] in
            try? await Task.sleep(for: pacing.handOver)
            guard !Task.isCancelled, let self, self.game.handoff != nil else { return }
            self.showsHandoff = true
        }
    }

    private func cancelHandoff() {
        handoffTask?.cancel()
        handoffTask = nil
    }

    private func save() {
        guard persists, !game.isOver else { return }
        DuelStore.save(game)
    }

    /// Для тестов: дождаться слоя передачи.
    func waitForHandoff() async {
        await handoffTask?.value
    }
}
