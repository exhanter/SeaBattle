//
//  PaperMatch.swift
//  Sea Battle — ход игры на бумаге (R3.1)
//
//  То, что в игре на бумаге происходит **между** правилами (`PaperGame`) и
//  экраном: какое поле показано, событие клетки для анимации, звук,
//  сохранение после каждого хода, итог партии и запись в статистику.
//
//  Та же роль, что у `BattleController` в бою против компьютера, но без
//  `AppState` и `PlayerData`: у этой партии нет ни компьютера, ни подсказок,
//  а поле противника — доска без флота. Поэтому отдельный тип, а не ветка в
//  бою: иначе каждое правило боя пришлось бы проверять ещё и «а если бумага».
//

import Foundation
import Observation

/// Пауза перед сменой поля. Параметром: тест проходит партию без ожидания,
/// а игроку нужно успеть увидеть ответ на своём поле.
struct PaperPacing: Sendable {
    /// После хода, отдавшего ход другому, — до перехода на другое поле.
    var handOver: Duration = .seconds(1.2)

    static let live = PaperPacing()
    static let instant = PaperPacing(handOver: .zero)
}

@MainActor
@Observable
final class PaperMatch {

    private(set) var game: PaperGame
    /// Поле на экране iPhone. Идёт за ходом сам (после паузы), но его можно
    /// переключить руками — посмотреть на другое поле.
    private(set) var shownField: Side
    /// Последнее событие клетки — ровно одно, анимации не копятся (спека 5).
    private(set) var lastEvent: CellEvent?
    /// Итог — в момент хода, закончившего партию; паузу держит экран.
    private(set) var result: MatchResult?

    @ObservationIgnored var soundOn = true
    @ObservationIgnored private let pacing: PaperPacing
    /// Тесты не пишут на диск: сохранение одно на приложение.
    @ObservationIgnored private let persists: Bool
    @ObservationIgnored private var nextEventID = 0
    @ObservationIgnored private var switchTask: Task<Void, Never>?

    init(game: PaperGame, pacing: PaperPacing = .live, persists: Bool = true) {
        self.game = game
        self.pacing = pacing
        self.persists = persists
        self.shownField = game.turn == .foe ? .you : .foe
    }

    // MARK: Такт 1 — ваш выстрел

    /// Касание поля противника: прицел ставится и свободно переносится.
    func tapFoe(_ coordinate: Coordinate) {
        guard game.aim != coordinate, game.aim(at: coordinate) else { return }
        if soundOn { AudioService.shared.play(.click) }
    }

    func answer(_ answer: PaperAnswer) {
        let before = game.foe
        guard let outcome = game.answer(answer) else { return }
        record(outcome, before: before, after: game.foe)
        HapticService.shared.play(outcome: outcome.call, incoming: false)
        if soundOn {
            switch answer {
            case .miss: AudioService.shared.play(.missed)
            case .hit: AudioService.shared.play(.hit)
            case .sunk: AudioService.shared.play(.sunk)
            }
        }
    }

    // MARK: Такт 2 — ход соперника

    /// Касание своего поля: названная соперником клетка.
    func tapOwn(_ coordinate: Coordinate) {
        let before = game.own
        guard let outcome = game.opponentShot(at: coordinate) else { return }
        record(outcome, before: before, after: game.own)
        HapticService.shared.play(outcome: outcome.call, incoming: true)
        if soundOn {
            AudioService.shared.play(outcome.call.isDamage ? .hit : .missed)
        }
    }

    // MARK: Откат

    var canUndo: Bool { game.canUndo }

    /// «Отменить последний ход». Событие гасится: анимировать откат нечем, и
    /// клетка просто возвращается в прежнее состояние.
    func undo() {
        guard game.undo() else { return }
        cancelSwitch()
        lastEvent = nil
        shownField = game.aim != nil || game.turn != .foe ? .foe : .you
        save()
        if soundOn { AudioService.shared.play(.click) }
        HapticService.shared.play(.button)
    }

    // MARK: Поле на экране

    func show(_ field: Side) {
        cancelSwitch()
        shownField = field
    }

    /// Событие для этого поля; чужое поле его не получает.
    func event(on field: Side) -> CellEvent? {
        lastEvent?.field == field ? lastEvent : nil
    }

    // MARK: Ход записан

    private func record(_ outcome: PaperOutcome, before: Board, after: Board) {
        lastEvent = CellEvent(id: nextEventID, field: outcome.field, target: outcome.coordinate,
                              outcome: outcome.call, before: before, after: after)
        nextEventID += 1
        save()
        if finishIfOver() { return }
        // Ход ушёл — через паузу на поле того, кто стреляет теперь.
        let next: Side = game.turn == .foe ? .you : .foe
        if next != shownField { scheduleSwitch(to: next) }
    }

    private func scheduleSwitch(to field: Side) {
        cancelSwitch()
        switchTask = Task { @MainActor [weak self, pacing] in
            try? await Task.sleep(for: pacing.handOver)
            guard !Task.isCancelled else { return }
            self?.shownField = field
        }
    }

    private func cancelSwitch() {
        switchTask?.cancel()
        switchTask = nil
    }

    /// Партия кончилась: итог, статистика в графу «игра на бумаге», баллов 0
    /// (решение заказчика 22.09 — результат вводит игрок), сохранения больше нет.
    @discardableResult
    private func finishIfOver() -> Bool {
        guard result == nil, let winner = game.winner else { return false }
        let didWin = winner == .you
        if persists {
            if didWin { ProgressStore.shared.recordWin(.paper) } else { ProgressStore.shared.recordLoss(.paper) }
            PaperStore.clear()
        }
        result = MatchResult(didWin: didWin, key: .paper,
                             yourLosses: game.own.sunkShipCount,
                             foeLosses: game.foe.sunkShipCount,
                             tally: game.tally,
                             balance: ProgressStore.shared.points)
        return true
    }

    private func save() {
        guard persists, !game.isOver else { return }
        PaperStore.save(game)
    }

    /// Для тестов: дождаться смены поля.
    func waitForSwitch() async {
        await switchTask?.value
    }
}
