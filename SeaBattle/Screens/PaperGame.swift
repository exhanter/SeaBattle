//
//  PaperGame.swift
//  Sea Battle — игра на бумаге без SwiftUI (R3.1)
//
//  Спека 4.6. Соперник играет на другом устройстве или на листе бумаги,
//  координаты называют вслух. Приложение **не знает его флот**: поле
//  противника — доска без кораблей, на которую ставятся ответы соперника
//  (`Board.mark`, `markSunkRun`). Своё поле — обычная доска с флотом: по
//  названной соперником клетке приложение само считает результат.
//
//  Два такта:
//  1. **Ваш выстрел.** Касание клетки поля противника ставит прицел — он
//     свободно переносится, пока не нажат ответ. Ответ «Мимо / Ранен / Убит»
//     записывает ход; «Убит» закрашивает всю связку попаданий.
//  2. **Ход соперника.** Касание названной клетки своего поля — выстрел по
//     ядру, результат приходит капсулой: что сказать вслух.
//
//  «Отменить последний ход» откатывает **ровно один** ход (4.6): прежнее
//  состояние хранится одно, без истории, и после отмены кнопка гаснет до
//  следующего хода.
//
//  Вынесено из экрана, как `FleetEditor` и `MatchResult`: правил здесь больше,
//  чем кажется, и каждое проверяется тестом, а не нажатиями.
//

import Foundation

// MARK: - Ответ соперника

/// Что соперник ответил на ваш выстрел. «Убит» — только вручную, по его слову:
/// флота соперника приложение не видит (4.6).
enum PaperAnswer: String, Codable, Sendable, CaseIterable {
    case miss, hit, sunk
}

/// Результат хода — то, что показывает капсула (одна на оба такта, 4.6):
/// на вашем выстреле — что ответили, на ходе соперника — что сказать вслух.
struct PaperOutcome: Codable, Equatable, Sendable {
    /// Поле, по которому стреляли: `.foe` — ваш выстрел, `.you` — соперника.
    let field: Side
    let coordinate: Coordinate
    let call: FeedOutcome
}

// MARK: - Партия

struct PaperGame: Codable, Equatable, Sendable {

    /// Всё, что откатывает «Отменить последний ход». Отдельным типом, чтобы
    /// откат был одним присваиванием и ничего нельзя было забыть вернуть.
    struct State: Codable, Equatable, Sendable {
        var own: Board
        var foe = Board()
        /// Чей ход. `nil` — ходов ещё не было: первым может стрелять любой
        /// (кто начинает, договариваются вслух, приложению это неизвестно).
        var turn: Side?
        /// Названная клетка, ответа ещё нет. Только на вашем ходу.
        var aim: Coordinate?
        /// Последний записанный ход — его показывает капсула.
        var last: PaperOutcome?
        /// Ваши выстрелы для итогов.
        var tally = MatchTally()
        var moves = 0
    }

    private(set) var state: State
    /// Состояние до последнего хода. Одно, без истории: дальше одного хода
    /// игра не откатывается (4.6).
    private(set) var undoState: State?
    /// «Обводка потопленного промахами» (4.5, 4.6) — настройка; на партию
    /// запоминается при старте, чтобы откат и продолжение шли по тем же правилам.
    let revealsRing: Bool

    init(fleet: [ShipPlacement], revealsRing: Bool = false) {
        self.state = State(own: Board(ships: fleet))
        self.revealsRing = revealsRing
    }

    // MARK: Чтение

    var own: Board { state.own }
    var foe: Board { state.foe }
    var turn: Side? { state.turn }
    var aim: Coordinate? { state.aim }
    var last: PaperOutcome? { state.last }
    var tally: MatchTally { state.tally }
    var moves: Int { state.moves }

    /// Победитель: `.you` — вы потопили все десять, `.foe` — соперник ваши.
    var winner: Side? {
        if state.foe.isFleetDestroyed { return .you }
        if state.own.isFleetDestroyed { return .foe }
        return nil
    }

    var isOver: Bool { winner != nil }

    /// Можно ли сейчас стрелять вам (такт 1). До первого хода — можно обоим.
    var acceptsYourShot: Bool { !isOver && state.turn != .foe }
    /// Можно ли сейчас записать выстрел соперника (такт 2).
    var acceptsOpponentShot: Bool { !isOver && state.turn != .you }

    /// Результат хода соперника — что сказать вслух (4.6). Капсула держится
    /// до следующего касания: назвали свою клетку — её место занимают ответы.
    var opponentCall: FeedOutcome? {
        guard let last = state.last, last.field == .you, state.aim == nil else { return nil }
        return last.call
    }

    /// Метка последнего попадания соперника на своём поле (4.6, раунд 8): стоит,
    /// пока он думает над следующим выстрелом, при промахе гаснет.
    var foeMark: Coordinate? {
        guard let last = state.last, last.field == .you, last.call.isDamage else { return nil }
        return last.coordinate
    }

    /// Откат есть после каждого хода, кроме последнего в партии: партия
    /// кончилась — итоги уже записаны.
    var canUndo: Bool { undoState != nil && !isOver }

    // MARK: Такт 1 — ваш выстрел

    /// Касание клетки поля противника. Прицел ставится только на нетронутую
    /// клетку и переносится свободно, пока нет ответа. Касание прицела ещё раз
    /// его не снимает: ответ нажимают внизу.
    @discardableResult
    mutating func aim(at coordinate: Coordinate) -> Bool {
        guard acceptsYourShot, coordinate.isOnBoard,
              state.foe[coordinate] == .water else { return false }
        state.aim = coordinate
        return true
    }

    mutating func clearAim() {
        state.aim = nil
    }

    /// Ответ соперника на названную клетку. «Ранен» и «Убит» оставляют ход
    /// вам, «Мимо» отдаёт его сопернику.
    @discardableResult
    mutating func answer(_ answer: PaperAnswer) -> PaperOutcome? {
        guard acceptsYourShot, let target = state.aim else { return nil }
        undoState = state

        var foe = state.foe
        let call: FeedOutcome
        switch answer {
        case .miss:
            foe.mark(.miss, at: target)
            call = .miss
            state.tally.record(.miss)
        case .hit:
            foe.mark(.hit, at: target)
            call = .hit
            state.tally.record(.hit(shipID: nil))
        case .sunk:
            foe.mark(.hit, at: target)
            foe.markSunkRun(from: target)
            if revealsRing { Self.revealRing(around: target, on: &foe) }
            call = .sunk
            state.tally.record(.hit(shipID: nil))
        }

        let outcome = PaperOutcome(field: .foe, coordinate: target, call: call)
        state.foe = foe
        state.aim = nil
        state.turn = answer == .miss ? .foe : .you
        state.last = outcome
        state.moves += 1
        return outcome
    }

    /// Вода вокруг потопленной связки становится промахами. Корабль на доске
    /// неизвестен, поэтому кольцо считается от самих клеток связки.
    private static func revealRing(around cell: Coordinate, on board: inout Board) {
        guard let run = board.sunkClusters().first(where: { $0.contains(cell) }) else { return }
        for neighbour in run.flatMap(\.neighbours) where board[neighbour] == .water {
            board.mark(.miss, at: neighbour)
        }
    }

    // MARK: Такт 2 — ход соперника

    /// Соперник назвал клетку: результат считает ядро по своему флоту.
    /// Попадание оставляет ход сопернику, промах и повторный выстрел — отдают
    /// вам, как в любом другом режиме (4.5).
    @discardableResult
    mutating func opponentShot(at coordinate: Coordinate) -> PaperOutcome? {
        guard acceptsOpponentShot, coordinate.isOnBoard else { return nil }
        undoState = state

        let result = state.own.apply(shotAt: coordinate)
        guard let call = FeedOutcome(result) else {
            undoState = nil
            return nil
        }
        let outcome = PaperOutcome(field: .you, coordinate: coordinate, call: call)
        state.aim = nil
        state.turn = result.keepsTurn ? .foe : .you
        state.last = outcome
        state.moves += 1
        return outcome
    }

    // MARK: Откат

    /// «Отменить последний ход»: ровно один ход. Прицел возвращается туда, где
    /// стоял, — после отката ответа можно сразу нажать другой.
    @discardableResult
    mutating func undo() -> Bool {
        guard canUndo, let previous = undoState else { return false }
        state = previous
        undoState = nil
        return true
    }
}
