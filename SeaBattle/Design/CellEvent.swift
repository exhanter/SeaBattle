//
//  CellEvent.swift
//  Sea Battle — событие клетки и его расписание (R2.4)
//
//  Спека 5, таблица 14c в макетах. Схема одна на все события: **в момент
//  выстрела одновременно стартуют** всплеск (два кольца), смена состояния
//  клетки и подсветка контура. Отложенных фаз нет; единственная задержка —
//  волна по корпусу при потоплении, 60 мс на клетку, не больше 240.
//
//  Здесь только данные и время, без SwiftUI: что сменилось, когда начинается
//  и сколько идёт. Рисует `BoardView`. Разделено ради теста — ошибка в
//  расписании на глаз не видна, а под тестом видна сразу.
//
//  **Анимации не копятся** по построению: у боя есть ровно одно «последнее
//  событие». Новое заменяет прежнее, и клетки прежнего сразу стоят в конечном
//  состоянии — очереди нет, и доигрывать нечего.
//

import Foundation

/// Одна клетка, у которой выстрел сменил состояние.
struct CellChange: Equatable, Sendable {
    let coordinate: Coordinate
    /// Что было до выстрела. Конечное состояние берётся из самой доски.
    let from: CellState
    /// От момента выстрела, в секундах. Ненулевая только в волне потопления.
    let delay: Double
    let duration: Double
    /// Смена состояния — ease-in-out, воронки обводки — ease-out (14c).
    var curve: Curve = .easeInOut

    enum Curve: Equatable, Sendable { case easeInOut, easeOut }
}

struct CellEvent: Equatable, Sendable {

    /// Номер в партии: два выстрела подряд в одну клетку (повторный) — это
    /// два события, и второе обязано перезапустить анимацию.
    let id: Int
    /// Чьё поле: от него цвет кольца и подсветки (правило 3).
    let field: Side
    let target: Coordinate
    let outcome: FeedOutcome
    let changes: [CellChange]
    let start: Date

    /// Строится из доски до и после выстрела. Дифф, а не разбор результата:
    /// так потопление, раскрытая обводка промахами и сама клетка выстрела
    /// попадают в список одним правилом, и ни одна из них не забудется.
    ///
    /// Для поля противника передавать `opponentView()` обеих досок — иначе
    /// в событие попадёт то, чего игрок не видит.
    init?(id: Int, field: Side, target: Coordinate, result: Board.ShotResult,
          before: Board, after: Board, start: Date = .now) {
        guard let outcome = FeedOutcome(result) else { return nil }
        self.init(id: id, field: field, target: target, outcome: outcome,
                  before: before, after: after, start: start)
    }

    /// Из исхода, а не из выстрела по ядру: в игре на бумаге ответ соперника
    /// ставится на доску вручную, и `ShotResult` у него нет (R3.1).
    init(id: Int, field: Side, target: Coordinate, outcome: FeedOutcome,
         before: Board, after: Board, start: Date = .now) {
        self.id = id
        self.field = field
        self.target = target
        self.outcome = outcome
        self.start = start
        self.changes = Self.schedule(target: target, before: before, after: after)
    }

    /// Цвет кольца и подсветки закреплён за полем: свои клетки — латунь,
    /// клетки противника — огонь. Белого нет, переключателя нет.
    var tone: Tone { field == .you ? .brass : .fire }

    enum Tone: Equatable, Sendable { case brass, fire }

    func change(at coordinate: Coordinate) -> CellChange? {
        changes.first { $0.coordinate == coordinate }
    }

    // MARK: Расписание

    /// Обводка промахами вокруг потопленного (таблица 14c): 200 мс, ease-out.
    /// Своего токена в `Motion` нет.
    static let outlineDuration: Double = 0.200
    /// Предел волны по корпусу (спека 5).
    static let sinkWaveLimit: Double = 0.240

    private static func schedule(target: Coordinate, before: Board, after: Board) -> [CellChange] {
        let changed = Board.allCoordinates.filter { before[$0] != after[$0] }

        // Волна идёт от клетки выстрела по корпусу: чем дальше клетка, тем
        // позже. Клетка выстрела — ноль, как и у любого другого события.
        var hull: [Coordinate: Double] = [:]
        for cell in changed where after[cell] == .sunk {
            let steps = abs(cell.row - target.row) + abs(cell.column - target.column)
            hull[cell] = min(Double(steps) * Motion.sinkPerCell, sinkWaveLimit)
        }

        return changed.map { cell in
            if let delay = hull[cell] {
                return CellChange(coordinate: cell, from: before[cell], delay: delay,
                                  duration: Motion.stateSwap)
            }
            if cell != target, after[cell] == .miss {
                // Воронка обводки идёт вместе с ближайшей клеткой корпуса —
                // волна продолжается наружу, а не начинается отдельной фазой.
                let delay = hull
                    .filter { max(abs($0.key.row - cell.row), abs($0.key.column - cell.column)) == 1 }
                    .map(\.value).min() ?? 0
                return CellChange(coordinate: cell, from: before[cell], delay: delay,
                                  duration: outlineDuration, curve: .easeOut)
            }
            return CellChange(coordinate: cell, from: before[cell], delay: 0,
                              duration: Motion.stateSwap)
        }
    }
}

// MARK: - Время

/// Где в своей анимации каждый слой в момент `t` (секунды от выстрела).
/// Reduce Motion — длительности × 0,5 (спека 5); что масштаб становится
/// прозрачностью, решает отрисовка.
struct CellEventTiming: Equatable, Sendable {
    let reduceMotion: Bool

    /// Второе кольцо идёт за первым со сдвигом 50 мс (таблица 14c).
    static let secondRingLag: Double = 0.050

    private func scaled(_ d: Double) -> Double { Motion.scaled(d, reduceMotion: reduceMotion) }

    /// Прогресс кольца 0…1 с кривой ease-out; `nil` — кольца сейчас нет.
    func ring(_ index: Int, at t: Double) -> Double? {
        let begin = index == 0 ? 0 : scaled(Self.secondRingLag)
        let x = (t - begin) / scaled(Motion.splash)
        guard x > 0, x < 1 else { return nil }
        return Self.easeOut(x)
    }

    /// Непрозрачность подсветки контура: зажигается в один кадр с выстрелом
    /// и гаснет за 520 мс (ease-out).
    func contour(at t: Double) -> Double {
        let x = t / scaled(Motion.contourGlow)
        guard x >= 0, x < 1 else { return 0 }
        return 1 - Self.easeOut(x)
    }

    /// Смена состояния клетки 0…1: 0 — ещё прежнее, 1 — уже конечное.
    /// Потопление — ease-in-out, обводка промахами — ease-out.
    func swap(_ change: CellChange, at t: Double) -> Double {
        let x = (t - scaled(change.delay)) / scaled(change.duration)
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return change.curve == .easeOut ? Self.easeOut(x) : Self.easeInOut(x)
    }

    /// Когда у клетки всё доиграно.
    func end(of change: CellChange) -> Double {
        scaled(change.delay + change.duration)
    }

    /// Когда кончаются кольца и подсветка у клетки выстрела.
    var effectsEnd: Double {
        max(scaled(Self.secondRingLag + Motion.splash), scaled(Motion.contourGlow))
    }

    /// Кубическая ease-out — та же, что в живых макетах 14d.
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}
