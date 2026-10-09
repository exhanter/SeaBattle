//
//  BattleController.swift
//  Sea Battle — ход боя против компьютера (R2.3)
//
//  Всё, что в бою происходит **между** правилами и экраном: прицел при
//  подтверждении выстрела, ход компьютера с паузами, лента «По вам за этот
//  раунд», подсказка, какое поле сейчас показано. Правил тут нет — выстрел
//  разбирает `GameEngine` через ядро, стрельбу компьютера выбирает
//  `ComputerOpponent`.
//
//  Вынесено из экрана по той же причине, что `FleetEditor` у расстановки:
//  поведения здесь больше, чем кажется, и каждое правило проверяется тестом,
//  а не нажатиями. Живёт в оболочке, а не в экране: ход компьютера не должен
//  обрываться от того, что игрок вышел в меню.
//

import Foundation
import Observation

// MARK: - Лента выстрелов

/// Чем кончился один выстрел — так, как его пишет лента (спека 2.8, 4.5).
/// `Codable` — ради игры на бумаге: там исход лежит в сохранении (`PaperOutcome`).
enum FeedOutcome: Codable, Equatable, Sendable {
    case miss
    case hit
    case sunk
    /// Повторный выстрел по раненой или убитой клетке.
    case repeatHit
    /// Повторный выстрел по воронке.
    case repeatMiss

    init?(_ result: Board.ShotResult) {
        switch result {
        case .miss: self = .miss
        case .hit: self = .hit
        case .sunk: self = .sunk
        case .repeated(let state): self = state.holdsKnownShip ? .repeatHit : .repeatMiss
        case .offBoard: return nil
        }
    }

    /// Урон по кораблю: такие капсулы тёплые, промахи — нейтральные.
    var isDamage: Bool { self == .hit || self == .sunk }
}

/// `Codable` — ради игры вдвоём: лента «По вам» лежит в её сохранении.
struct ShotFeedEntry: Identifiable, Codable, Equatable, Sendable {
    /// Порядковый номер в партии: капсулы с одной клеткой (повторный выстрел)
    /// не должны сливаться в одну.
    let id: Int
    let coordinate: Coordinate
    let outcome: FeedOutcome
}

// MARK: - Паузы

/// Паузы хода компьютера. Параметром, а не константами по месту: тест
/// проигрывает целый ход без ожидания, а игроку нужно успеть увидеть свой
/// промах до того, как экран уйдёт на его поле.
struct BattlePacing: Sendable {
    /// После промаха игрока — до перехода на своё поле.
    var handOver: Duration = .seconds(1.0)
    /// На своём поле — до первого выстрела компьютера.
    var beforeFirstShot: Duration = .seconds(0.8)
    /// Между выстрелами компьютера, пока он попадает.
    var betweenShots: Duration = .seconds(1.0)
    /// После промаха компьютера — до возврата на поле противника.
    var backToFoe: Duration = .seconds(1.2)

    static let live = BattlePacing()
    static let instant = BattlePacing(handOver: .zero, beforeFirstShot: .zero,
                                      betweenShots: .zero, backToFoe: .zero)
}

// MARK: - Контроллер

@MainActor
@Observable
final class BattleController {

    /// Поля живут здесь, а контроллер — в оболочке: партия не должна теряться
    /// от того, что игрок вышел в меню посмотреть статистику. Сами объекты не
    /// пересоздаются никогда — новая партия чистит их на месте
    /// (`AppState.resetData`), поэтому компьютер, привязанный к ним однажды,
    /// остаётся годен.
    let player = PlayerData(side: .you)
    let enemy = PlayerData(side: .foe)

    /// «По вам за этот раунд» — выстрелы компьютера за его последний ход.
    private(set) var incoming: [ShotFeedEntry] = []
    /// Последний выстрел — по любому полю. Ровно одно: новое событие
    /// заменяет прежнее, поэтому анимации не копятся (спека 5).
    private(set) var lastEvent: CellEvent?
    /// Итог партии — ставится **в момент** последнего выстрела, а не через
    /// секунду, как старое окно: паузу перед итогами держит экран
    /// (`Motion.toResults`), а тесту ждать нечего (R2.5).
    private(set) var result: MatchResult?
    /// Выстрелы, серия и подсказки игрока — для итогов и для сохранения.
    @ObservationIgnored private(set) var tally = MatchTally()

    @ObservationIgnored private(set) var appState: AppState?
    @ObservationIgnored private let engine = GameEngine()
    @ObservationIgnored private var opponent: ComputerOpponent?
    @ObservationIgnored private let pacing: BattlePacing
    @ObservationIgnored private var nextEntryID = 0
    @ObservationIgnored private var nextEventID = 0
    /// Ход компьютера. Держим ссылку, чтобы новая партия его обрывала: иначе
    /// досыпающий ход прошлой партии стрелял бы по свежему полю.
    @ObservationIgnored private var turnTask: Task<Void, Never>?
    @ObservationIgnored private var turnGeneration = 0

    init(pacing: BattlePacing = .live) {
        self.pacing = pacing
    }

    /// Один раз, когда оболочка на экране и `AppState` доступен.
    func configure(appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState
        engine.configure(appState: appState, player: player, enemy: enemy)
        opponent = ComputerOpponent(appState: appState, ownFleet: enemy, targetBoard: player)
    }

    // MARK: Партия

    /// Новая или продолженная партия: всё временное — лента, ход компьютера,
    /// итог — сбрасывается, поля не трогаются (их готовит вызывающий).
    /// Продолженная партия приносит свой счёт из сохранения.
    func beginMatch(tally: MatchTally = MatchTally()) {
        cancelOpponentTurn()
        incoming = []
        lastEvent = nil
        result = nil
        self.tally = tally
    }

    var isPlayersTurn: Bool {
        guard let appState else { return false }
        return appState.gameIsActive && !appState.enemysTurn
    }

    var isOpponentThinking: Bool { turnTask != nil }

    // MARK: Выстрел игрока

    /// Касание клетки поля противника — сразу выстрел.
    func tap(_ coordinate: Coordinate) {
        guard isPlayersTurn else { return }
        fire(at: coordinate)
    }

    private func fire(at coordinate: Coordinate) {
        guard let appState else { return }
        let result = shoot(at: coordinate, on: enemy)
        if appState.soundOn { playOwnShot(result) }
        HapticService.shared.play(shot: result, incoming: false)
        autosave()
        if appState.gameIsActive && appState.enemysTurn {
            startOpponentTurn()
        }
    }

    /// Свой выстрел озвучивается здесь: движок голосит только выстрелы по
    /// игроку. Повторный выстрел отыгрывается всплеском, как промах (4.5).
    private func playOwnShot(_ result: Board.ShotResult) {
        switch result {
        case .miss, .repeated: AudioService.shared.play(.missed)
        case .hit: AudioService.shared.play(.hit)
        case .sunk: AudioService.shared.play(.sunk)
        case .offBoard: break
        }
    }

    // MARK: Ход компьютера

    private func startOpponentTurn() {
        cancelOpponentTurn()
        turnGeneration += 1
        let generation = turnGeneration
        turnTask = Task { @MainActor [weak self] in
            await self?.runOpponentTurn()
            // Закончившийся ход снимает только **свою** ссылку: новая партия
            // могла уже поставить на её место другой ход.
            if self?.turnGeneration == generation { self?.turnTask = nil }
        }
    }

    private func cancelOpponentTurn() {
        turnTask?.cancel()
        turnTask = nil
    }

    /// Один ход целиком: стрелять, пока попадает. Паузы нужны игроку — без
    /// них промах, переход на своё поле и три выстрела компьютера слились бы
    /// в один кадр.
    private func runOpponentTurn() async {
        guard let appState, let opponent else { return }

        try? await Task.sleep(for: pacing.handOver)
        guard !Task.isCancelled else { return }
        incoming = []
        show(.you)
        try? await Task.sleep(for: pacing.beforeFirstShot)

        while !Task.isCancelled {
            let shot = await opponent.nextShot()
            guard !Task.isCancelled else { return }
            let result = shoot(at: shot, on: player)
            log(shot, result)
            guard result.keepsTurn, appState.gameIsActive else { break }
            try? await Task.sleep(for: pacing.betweenShots)
        }
        guard !Task.isCancelled else { return }

        // Ход вернулся к игроку — стабильная точка для сохранения.
        autosave()
        guard appState.gameIsActive else { return }
        try? await Task.sleep(for: pacing.backToFoe)
        guard !Task.isCancelled else { return }
        show(.foe)
    }

    /// Выстрел плюс событие клетки для экрана. Поле противника сравнивается
    /// так, как его видит игрок (`opponentView()`): иначе событие выдало бы
    /// нетронутые корабли.
    private func shoot(at coordinate: Coordinate, on target: PlayerData) -> Board.ShotResult {
        let visible = { target.side == .foe ? target.coreBoard.opponentView() : target.coreBoard }
        let before = visible()
        let result = engine.checkShipOnFire(row: coordinate.row, column: coordinate.column,
                                            target: target)
        if let event = CellEvent(id: nextEventID, field: target.side, target: coordinate,
                                 result: result, before: before, after: visible()) {
            lastEvent = event
            nextEventID += 1
        }
        if target.side == .foe { tally.record(result) }
        finishIfOver()
        return result
    }

    /// Партию кончает любой выстрел — и свой, и компьютера. Баланс берётся
    /// после `GameEngine.finish`, поэтому победа в нём уже начислена — как и
    /// партия в счёте уровня.
    private func finishIfOver() {
        guard result == nil, let appState, appState.gameIsOver else { return }
        let level = appState.difficultyLevel
        result = MatchResult(didWin: enemy.coreBoard.isFleetDestroyed,
                             level: level,
                             yourLosses: player.numberShipsDestroyed,
                             foeLosses: enemy.numberShipsDestroyed,
                             tally: tally,
                             balance: ProgressStore.shared.points,
                             levelRecord: ProgressStore.shared.record(.computer(level)))
    }

    /// Событие для показанного поля; чужое поле его не получает.
    func event(on field: Side) -> CellEvent? {
        lastEvent?.field == field ? lastEvent : nil
    }

    private func log(_ shot: Coordinate, _ result: Board.ShotResult) {
        guard let outcome = FeedOutcome(result) else { return }
        incoming.append(ShotFeedEntry(id: nextEntryID, coordinate: shot, outcome: outcome))
        nextEntryID += 1
    }

    // MARK: Какое поле на экране

    /// Показанное поле хранится в `AppState.selectedTab`, как у старого боя:
    /// на нём держатся «Продолжить партию» и итоги, а два источника одного
    /// факта разошлись бы.
    var shownField: Side {
        appState?.selectedTab == .playerView ? .you : .foe
    }

    func show(_ field: Side) {
        guard let appState else { return }
        // Ход компьютера доигрывает и тогда, когда игрок вышел в меню. Вернуть
        // его оттуда на поле посреди статистики нельзя.
        guard appState.selectedTab == .playerView || appState.selectedTab == .enemyView else { return }
        appState.selectedTab = field == .you ? .playerView : .enemyView
    }

    // MARK: Подсказка

    /// Цена подсказки на текущем уровне — она же награда за победу.
    var hintCost: Int { appState?.difficultyLevel.pointsValue ?? 0 }

    var canUseHint: Bool {
        isPlayersTurn && ProgressStore.shared.points >= hintCost && !hintCandidates.isEmpty
    }

    /// Открывает случайную клетку, где точно стоит непотопленный корабль и по
    /// которой ещё не стреляли. Логика та же, что у старой кнопки.
    @discardableResult
    func requestHint() -> Bool {
        guard let appState, canUseHint,
              let pick = hintCandidates.randomElement(),
              ProgressStore.shared.spendOnHint(hintCost) else { return false }
        appState.revealedHintCells.append(pick.tuple)
        tally.recordHint(cost: hintCost)
        if appState.soundOn { AudioService.shared.play(.click) }
        HapticService.shared.play(.button)
        return true
    }

    var hintCells: Set<Coordinate> {
        Set(appState?.revealedHintCells.map(Coordinate.init) ?? [])
    }

    private var hintCandidates: [Coordinate] {
        let shown = hintCells
        let board = enemy.coreBoard
        return enemy.ships
            .filter { !$0.isDestroyed }
            .flatMap { $0.coordinates.map(Coordinate.init) }
            .filter { board[$0] == .ship && !shown.contains($0) }
    }

    // MARK: Сохранение

    /// Только в стабильных точках — на ходу игрока при идущей партии. Поэтому
    /// продолжение всегда попадает на «игрок стреляет», и недоигранного хода
    /// компьютера после загрузки не бывает.
    private func autosave() {
        guard let appState, appState.gameIsActive, !appState.enemysTurn else { return }
        GameStore.save(snapshot(of: appState))
    }

    /// Снимок партии вместе со счётом игрока — один на все места, где пишется
    /// сохранение, чтобы счёт не потерялся ни в одном из них.
    func snapshot(of appState: AppState) -> GameSnapshot {
        GameSnapshot(appState: appState, player: player, enemy: enemy, tally: tally)
    }

    /// Для тестов: дождаться, пока компьютер доиграет ход.
    func waitForOpponent() async {
        await turnTask?.value
    }
}
