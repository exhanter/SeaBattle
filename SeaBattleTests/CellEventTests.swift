//
//  CellEventTests.swift
//  SeaBattleTests
//
//  R2.4 — события клетки. Проверяется расписание, а не картинка: какие
//  клетки меняются, в каком порядке идёт волна, когда кончается каждый слой,
//  что бой держит ровно одно последнее событие. Ошибка в любом из этих мест
//  на глаз почти не видна — анимация просто «какая-то не такая».
//

import Testing
import Foundation
@testable import SeaBattle

@MainActor
@Suite("События клетки")
struct CellEventTests {

    /// Трёхпалубник по горизонтали: Б2–Г2 (ряд 2, столбцы 2…4).
    private let ship = ShipPlacement(length: 3, origin: Coordinate(row: 2, column: 2),
                                     orientation: .horizontal)

    private func event(shootingAt target: Coordinate, on board: inout Board,
                       revealRing: Bool = false) -> CellEvent? {
        let before = board
        let result = board.apply(shotAt: target)
        if revealRing, case .sunk(let sunk) = result { board.revealRing(around: sunk) }
        return CellEvent(id: 0, field: .foe, target: target, result: result,
                         before: before, after: board, start: .distantPast)
    }

    // MARK: Что меняется

    @Test("Промах и попадание меняют одну клетку, без задержки")
    func aSingleShotChangesOneCell() throws {
        var board = Board(ships: [ship])
        let miss = try #require(event(shootingAt: Coordinate(row: 8, column: 8), on: &board))
        #expect(miss.outcome == .miss)
        #expect(miss.changes == [CellChange(coordinate: Coordinate(row: 8, column: 8),
                                            from: .water, delay: 0, duration: Motion.stateSwap)])

        let hit = try #require(event(shootingAt: Coordinate(row: 2, column: 3), on: &board))
        #expect(hit.outcome == .hit)
        #expect(hit.changes.map(\.coordinate) == [Coordinate(row: 2, column: 3)])
        #expect(hit.changes.first?.from == .ship)
    }

    @Test("Повторный выстрел: событие есть, клетки не меняются")
    func aRepeatShotStillPlays() throws {
        var board = Board(ships: [ship])
        _ = board.apply(shotAt: Coordinate(row: 5, column: 5))
        let again = try #require(event(shootingAt: Coordinate(row: 5, column: 5), on: &board))
        #expect(again.outcome == .repeatMiss)
        #expect(again.changes.isEmpty)
    }

    @Test("Потопление — волна от клетки выстрела, 60 мс на клетку")
    func sinkingRunsAsAWave() throws {
        var board = Board(ships: [ship])
        _ = board.apply(shotAt: Coordinate(row: 2, column: 2))
        _ = board.apply(shotAt: Coordinate(row: 2, column: 3))
        // Добивающий выстрел — по краю корабля, волна идёт в одну сторону.
        let sunk = try #require(event(shootingAt: Coordinate(row: 2, column: 4), on: &board))
        #expect(sunk.outcome == .sunk)

        let delays = Dictionary(uniqueKeysWithValues: sunk.changes.map { ($0.coordinate.column, $0.delay) })
        #expect(delays == [4: 0, 3: Motion.sinkPerCell, 2: 2 * Motion.sinkPerCell])
        #expect(sunk.change(at: Coordinate(row: 2, column: 2))?.from == .hit)
        #expect(sunk.change(at: Coordinate(row: 2, column: 4))?.from == .ship)
    }

    @Test("Волна потопления не длиннее 240 мс")
    func theWaveIsCapped() throws {
        let long = ShipPlacement(length: 4, origin: Coordinate(row: 1, column: 1),
                                 orientation: .vertical)
        var board = Board(ships: [long])
        for row in 2...4 { _ = board.apply(shotAt: Coordinate(row: row, column: 1)) }
        let sunk = try #require(event(shootingAt: Coordinate(row: 1, column: 1), on: &board))
        #expect(sunk.changes.allSatisfy { $0.delay <= CellEvent.sinkWaveLimit })
        #expect(sunk.changes.map(\.delay).max() == 3 * Motion.sinkPerCell)
    }

    @Test("Обводка промахами идёт вместе с волной, а не отдельной фазой")
    func theOutlineFollowsTheWave() throws {
        var board = Board(ships: [ship])
        _ = board.apply(shotAt: Coordinate(row: 2, column: 2))
        _ = board.apply(shotAt: Coordinate(row: 2, column: 3))
        let sunk = try #require(event(shootingAt: Coordinate(row: 2, column: 4), on: &board,
                                      revealRing: true))

        let ring = sunk.changes.filter { $0.duration == CellEvent.outlineDuration }
        #expect(ring.count == ship.ring.filter(\.isOnBoard).count)
        #expect(ring.allSatisfy { $0.curve == .easeOut && $0.from == .water })
        // Воронка у дальнего конца стартует с дальней клеткой корпуса.
        #expect(sunk.change(at: Coordinate(row: 2, column: 1))?.delay == 2 * Motion.sinkPerCell)
        #expect(sunk.change(at: Coordinate(row: 2, column: 5))?.delay == 0)
        #expect(sunk.changes.map(\.delay).max() ?? 0 <= CellEvent.sinkWaveLimit)
    }

    // MARK: Цвет

    @Test("Цвет закреплён за полем: своё — латунь, противника — огонь")
    func theToneBelongsToTheField() throws {
        let board = Board()
        let mine = try #require(CellEvent(id: 0, field: .you, target: Coordinate(row: 1, column: 1),
                                          result: .miss, before: board, after: board))
        let theirs = try #require(CellEvent(id: 1, field: .foe, target: Coordinate(row: 1, column: 1),
                                            result: .miss, before: board, after: board))
        #expect(mine.tone == .brass)
        #expect(theirs.tone == .fire)
    }

    // MARK: Время

    @Test("Всплеск, смена состояния и подсветка стартуют в момент выстрела")
    func everythingStartsTogether() {
        let timing = CellEventTiming(reduceMotion: false)
        let tick = 0.001
        #expect(timing.ring(0, at: tick) != nil)
        #expect(timing.contour(at: tick) > 0.99)
        let swap = CellChange(coordinate: Coordinate(row: 1, column: 1), from: .water,
                              delay: 0, duration: Motion.stateSwap)
        #expect(timing.swap(swap, at: tick) > 0)
        // Второе кольцо — через 50 мс, не раньше.
        #expect(timing.ring(1, at: tick) == nil)
        #expect(timing.ring(1, at: CellEventTiming.secondRingLag + tick) != nil)
    }

    @Test("Каждый слой кончается в свой срок")
    func eachLayerEndsOnTime() {
        let timing = CellEventTiming(reduceMotion: false)
        #expect(timing.ring(0, at: Motion.splash) == nil)
        #expect(timing.contour(at: Motion.contourGlow) == 0)
        let swap = CellChange(coordinate: Coordinate(row: 1, column: 1), from: .water,
                              delay: 0.06, duration: Motion.stateSwap)
        #expect(timing.swap(swap, at: 0.06) == 0)
        #expect(timing.swap(swap, at: 0.06 + Motion.stateSwap) == 1)
        #expect(timing.effectsEnd == Motion.contourGlow)
    }

    @Test("Reduce Motion: всё вдвое быстрее, кольцо не растёт")
    func reduceMotionHalvesTheClock() {
        let still = CellEventTiming(reduceMotion: true)
        #expect(still.ring(0, at: Motion.splash / 2) == nil)
        #expect(still.contour(at: Motion.contourGlow / 2) == 0)
        #expect(still.effectsEnd == Motion.contourGlow / 2)
        #expect(CellEffectMetrics.ringScale(progress: 0.1, reduceMotion: true)
                == CellEffectMetrics.ringScale(progress: 0.9, reduceMotion: true))
        #expect(CellEffectMetrics.ringScale(progress: 0.1, reduceMotion: false)
                < CellEffectMetrics.ringScale(progress: 0.9, reduceMotion: false))
    }

    @Test("Кривые не выходят за 0…1 и не идут назад")
    func curvesAreMonotone() {
        let xs = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 }
        for curve in [CellEventTiming.easeOut, CellEventTiming.easeInOut] {
            let ys = xs.map(curve)
            #expect(ys.first == 0 && ys.last == 1)
            #expect(zip(ys, ys.dropFirst()).allSatisfy { $0 <= $1 })
        }
    }

    // MARK: Бой

    private func match() -> (AppState, BattleController) {
        let appState = AppState()
        appState.soundOn = false
        // Явно: настройка общая через `UserDefaults`, а `BattleTests` рядом
        // её включают — первое касание поставило бы прицел вместо выстрела.
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

    @Test("Выстрел игрока — событие на поле противника, только на нём")
    func theShotLandsOnTheFoeField() throws {
        let (_, battle) = match()
        let cell = Coordinate(battle.enemy.ships[0].coordinates[0])
        battle.tap(cell)

        let event = try #require(battle.lastEvent)
        #expect(event.field == .foe && event.target == cell)
        #expect(battle.event(on: .foe) == event)
        #expect(battle.event(on: .you) == nil)
    }

    @Test("Событие поля противника не выдаёт корабль: попадание растворяется из воды")
    func theFoeEventHidesTheFleet() throws {
        let (_, battle) = match()
        let cell = Coordinate(battle.enemy.ships[0].coordinates[0])
        battle.tap(cell)
        let event = try #require(battle.lastEvent)
        #expect(event.changes.allSatisfy { $0.from != .ship })
        #expect(event.change(at: cell)?.from == .water)
    }

    @Test("Анимации не копятся: новое событие заменяет прежнее, новая партия чистит")
    func onlyTheLastEventLives() async throws {
        let (appState, battle) = match()
        let ship = battle.enemy.ships[0].coordinates.map(Coordinate.init)
        battle.tap(ship[0])
        let first = try #require(battle.lastEvent)

        // Промах отдаёт ход — компьютер стреляет по своему полю игрока.
        let water = Board.allCoordinates.first { battle.enemy.coreBoard[$0] == .water }!
        battle.tap(water)
        await battle.waitForOpponent()
        let last = try #require(battle.lastEvent)
        #expect(last.id > first.id)
        if appState.gameIsActive { #expect(last.field == .you) }

        battle.beginMatch()
        #expect(battle.lastEvent == nil)
    }
}
