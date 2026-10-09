//
//  NetMatch.swift
//  Sea Battle — ход сетевой партии (R3.3)
//
//  То, что происходит между правилами (`NetGame`) и экраном: транспорт,
//  событие клетки, звук, прицел, таймер хода, обрыв связи с переподключением,
//  выход соперника, итог и статистика. Та же роль, что у `DuelMatch` и
//  `BattleController`; транспорт любой — рядом (Multipeer) или по сети
//  (Game Center), правила у них одни, различается только графа статистики.
//
//  **Обрыв связи (4.8).** Партия живёт две минуты: баннер на месте панели
//  счёта, пять попыток переподключиться, «Повторить сейчас». Вернулась связь —
//  обе стороны досылают то, что ждёт ответа (`NetGame.resync`), и партия идёт
//  дальше с того же хода. Не вернулась — партия закрывается **без победы**:
//  ни одной из сторон, иначе выключить Wi-Fi было бы способом не проиграть
//  и способом выиграть одновременно. Победа зачитывается только при
//  осознанном выходе соперника (`.quit`).
//

import Foundation
import Observation

/// Сроки обрыва. Параметром: тест проходит обрыв без двухминутного ожидания.
struct NetPacing: Sendable {
    /// Сколько партия ждёт связь (4.8).
    var grace: Duration = .seconds(120)
    var attempts = 5

    static let live = NetPacing()
    static let instant = NetPacing(grace: .milliseconds(50), attempts: 5)

    /// Между попытками — поровну на весь срок.
    var betweenAttempts: Duration { grace / attempts }
}

/// Связь с соперником.
enum NetLink: Equatable, Sendable {
    case connected
    /// Связь пропала; идёт попытка `attempt` из `NetPacing.attempts`.
    case lost(since: Date, attempt: Int)
    /// Срок вышел — партия закрыта без победы.
    case closed

    var isLost: Bool {
        if case .lost = self { return true }
        return false
    }
}

/// Окно поверх погашенного боя.
enum NetNotice: Equatable, Sendable {
    /// Соперник вышел сам. `won` — посреди боя, победа зачтена вам; до боя
    /// или после итогов — просто ушёл.
    case opponentLeft(won: Bool)
    /// Связь не вернулась за две минуты.
    case connectionClosed
    /// У соперника другая версия приложения.
    case incompatible
}

@MainActor
@Observable
final class NetMatch {

    private(set) var game: NetGame
    /// Флот на расстановке, пока не нажато «Начать».
    var editor = FleetEditor()
    private(set) var link: NetLink = .connected
    private(set) var notice: NetNotice?
    /// Поле на экране. Ожидание хода — тоже на поле противника: оно не
    /// нажимается, а лента «По вам» наполняется под ним (кадр `screen5NetWait`).
    private(set) var shownField: Side = .foe
    private(set) var lastEvent: CellEvent?
    /// Итог на экране. При выходе соперника он готов сразу, а показывается
    /// по кнопке «К результатам» (`screen5NetLeft`).
    private(set) var result: MatchResult?
    /// Начало текущего хода — от него идёт таймер в холодной капсуле.
    private(set) var turnStarted = Date.now

    let statKey: StatKey
    var mode: GameMode { statKey.mode }

    @ObservationIgnored var soundOn = true
    @ObservationIgnored private let transport: any NetworkTransport
    @ObservationIgnored private let pacing: NetPacing
    /// Тесты не пишут статистику: хранилище одно на приложение.
    @ObservationIgnored private let records: Bool
    @ObservationIgnored private var nextEventID = 0
    @ObservationIgnored private var pendingResult: MatchResult?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var recordedRound: Int?

    init(transport: any NetworkTransport, statKey: StatKey, me: NetHello,
         revealsRing: Bool = false, pacing: NetPacing = .live, records: Bool = true) {
        self.transport = transport
        self.statKey = statKey
        self.game = NetGame(me: me, revealsRing: revealsRing)
        self.pacing = pacing
        self.records = records
    }

    /// Своё приветствие для этой партии: случайное число решает, кто первый.
    static func hello(name: String, glyph: String, colorIndex: Int, accountID: String) -> NetHello {
        NetHello(name: name, glyph: glyph, colorIndex: colorIndex, accountID: accountID,
                 nonce: UInt64.random(in: .min ... .max), version: NetGame.protocolVersion)
    }

    /// Подключение уже есть — поздороваться и слушать.
    func start() {
        transport.onReceive = { [weak self] message in self?.handle(message) }
        transport.onConnectionChange = { [weak self] connected in
            self?.connectionChanged(connected)
        }
        transport.send(game.hello)
    }

    // MARK: Чтение

    var opponentName: String { game.opponent?.name ?? "" }

    /// Соперник поздоровался. До этого флот можно расставлять, но не
    /// объявлять готовым (4.4).
    var hasOpponent: Bool { game.opponent != nil }

    /// Поле в роли экрана.
    func board(_ field: Side) -> Board {
        field == .you ? game.own : game.tracking
    }

    var incoming: [ShotFeedEntry] { game.incoming }

    var isMyTurn: Bool { game.isBattle && game.isMyTurn }

    /// Ждём соперника: он ещё расставляет флот или стреляет.
    var isWaiting: Bool {
        (game.stage == .arranging && game.isReady) || (game.isBattle && !game.isMyTurn)
    }

    func event(on field: Side) -> CellEvent? {
        lastEvent?.field == field ? lastEvent : nil
    }

    // MARK: Расстановка

    func finishArrangement() {
        guard game.stage == .arranging, !game.isReady else { return }
        let before = game.stage
        send(game.ready(fleet: editor.ships))
        if soundOn { AudioService.shared.play(.click) }
        HapticService.shared.play(.button)
        if before != game.stage { battleBegan() }
    }

    // MARK: Выстрел

    /// Касание поля противника — сразу выстрел.
    func tap(_ coordinate: Coordinate) {
        guard game.acceptsShot, shownField == .foe, !link.isLost else { return }
        if let message = game.fire(at: coordinate) { transport.send(message) }
    }

    func show(_ field: Side) {
        shownField = field
    }

    // MARK: Подсказка

    /// Ставка «Эксперта», как и награда за сетевую победу (R0.7).
    var hintCost: Int { AppState.DifficultyLevel.expert.pointsValue }

    /// Подсказка стоит вам баллов и платит сопернику, поэтому против своего
    /// же аккаунта её нет.
    var offersHint: Bool { !game.isSameAccount }

    var canUseHint: Bool {
        offersHint && game.canRequestHint && !link.isLost
            && ProgressStore.shared.points >= hintCost
    }

    func requestHint() {
        guard canUseHint, ProgressStore.shared.spendOnHint(hintCost),
              let message = game.requestHint() else { return }
        game.recordHint(cost: hintCost)
        transport.send(message)
        if soundOn { AudioService.shared.play(.click) }
        HapticService.shared.play(.button)
    }

    // MARK: Выход, итоги, серия

    /// «Меню» → «Сдаться и выйти» посреди боя, или просто уход до и после.
    /// Сдача пишется поражением — но не при оборванной связи: там партия
    /// закрывается без победы для обеих сторон.
    func leave() {
        let wasBattle = game.isBattle
        _ = game.leave()
        if link == .connected && wasBattle { record() }
        close()
    }

    /// «В меню» с итогов или из окна: соперник узнаёт, что ждать некого
    /// (`.quit`), связь больше не нужна.
    func close() {
        if link == .connected { transport.send(.quit) }
        // Сначала закрыть: разрыв, который вызовет `disconnect`, — наш, а не
        // обрыв, и переподключаться после него незачем.
        link = .closed
        cancelReconnect()
        transport.disconnect()
    }

    /// «К результатам» из окна «Соперник вышел».
    func showResult() {
        notice = nil
        result = pendingResult
    }

    /// «Ещё партия»: следующая партия серии. Если соперник уже ушёл, ждать
    /// некого — окно вместо расстановки.
    func playAgain() {
        guard !game.opponentLeft else {
            result = nil
            notice = .opponentLeft(won: false)
            return
        }
        guard let message = game.rematch() else { return }
        transport.send(message)
        editor = FleetEditor()
        result = nil
        pendingResult = nil
        lastEvent = nil
        shownField = .foe
    }

    // MARK: Сообщения

    private func handle(_ message: NetworkMessage) {
        let wasMyTurn = isMyTurn
        let stageBefore = game.stage
        let step = game.receive(message)
        send(step.replies)

        if step.incompatible {
            notice = .incompatible
            return
        }
        if let shot = step.shot { show(shot) }
        if step.compensated && !game.isSameAccount {
            ProgressStore.shared.receiveCompensation(hintCost)
        }
        if step.opponentQuit { opponentQuit(during: stageBefore) }
        if step.began || (stageBefore == .arranging && game.isBattle) { battleBegan() }
        if isMyTurn != wasMyTurn { turnStarted = .now }
        if stageBefore != .over && game.isOver && game.ending == .fleet { finish() }
    }

    private func send(_ messages: [NetworkMessage]) {
        messages.forEach(transport.send)
    }

    private func show(_ shot: NetGame.Shot) {
        lastEvent = CellEvent(id: nextEventID, field: shot.field, target: shot.at,
                              outcome: shot.outcome, before: shot.before, after: shot.after)
        nextEventID += 1
        HapticService.shared.play(outcome: shot.outcome, incoming: shot.field == .you)
        guard soundOn else { return }
        switch shot.outcome {
        case .miss, .repeatHit, .repeatMiss: AudioService.shared.play(.missed)
        case .hit: AudioService.shared.play(.hit)
        case .sunk: AudioService.shared.play(.sunk)
        }
    }

    private func battleBegan() {
        turnStarted = .now
        shownField = .foe
        lastEvent = nil
    }

    private func opponentQuit(during stage: NetGame.Stage) {
        switch stage {
        case .battle:
            // Осознанный выход посреди боя — победа ваша (4.8).
            record()
            pendingResult = makeResult()
            notice = .opponentLeft(won: true)
        case .arranging:
            notice = .opponentLeft(won: false)
        case .over:
            // На итогах: окна нет, «Ещё партия» скажет, что ждать некого.
            break
        }
        cancelReconnect()
        link = .connected
    }

    private func finish() {
        record()
        // Звук победы или поражения играют итоги сами.
        result = makeResult()
    }

    /// Статистика — один раз на партию серии, и не против своего аккаунта:
    /// победа над собой не победа, баллы с себя не фармятся.
    private func record() {
        guard records, recordedRound != game.round, !game.isSameAccount,
              let winner = game.winner else { return }
        recordedRound = game.round
        if winner == .you {
            ProgressStore.shared.recordWin(statKey)
        } else {
            ProgressStore.shared.recordLoss(statKey)
        }
    }

    private func makeResult() -> MatchResult {
        MatchResult(didWin: game.winner == .you, key: statKey,
                    yourLosses: game.own.sunkShipCount,
                    foeLosses: game.tracking.sunkShipCount,
                    tally: game.tally,
                    balance: ProgressStore.shared.points,
                    awardsPoints: !game.isSameAccount)
    }

    // MARK: Обрыв связи

    private func connectionChanged(_ connected: Bool) {
        if connected {
            guard link != .closed else { return }
            cancelReconnect()
            link = .connected
            transport.send(game.hello)
            return
        }
        // После итогов и после окна ждать нечего.
        guard link == .connected, !game.isOver, notice == nil else { return }
        link = .lost(since: .now, attempt: 1)
        transport.reconnect()
        startReconnecting()
    }

    /// «Повторить сейчас»: попытка вне очереди, срок партии не продлевается.
    func retryNow() {
        guard case .lost(let since, let attempt) = link else { return }
        link = .lost(since: since, attempt: min(attempt + 1, pacing.attempts))
        transport.reconnect()
    }

    private func startReconnecting() {
        cancelReconnect()
        reconnectTask = Task { @MainActor [weak self, pacing] in
            for _ in 1..<pacing.attempts {
                try? await Task.sleep(for: pacing.betweenAttempts)
                guard !Task.isCancelled, let self, case .lost(let since, let attempt) = self.link else {
                    return
                }
                self.link = .lost(since: since, attempt: min(attempt + 1, pacing.attempts))
                self.transport.reconnect()
            }
            try? await Task.sleep(for: pacing.betweenAttempts)
            guard !Task.isCancelled, let self, self.link.isLost else { return }
            self.link = .closed
            self.notice = .connectionClosed
            self.transport.disconnect()
        }
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    /// Сколько осталось до закрытия партии — в баннере.
    func remaining(at date: Date) -> Duration {
        guard case .lost(let since, _) = link else { return .zero }
        let left = pacing.grace - .seconds(date.timeIntervalSince(since))
        return max(.zero, left)
    }

    /// Для тестов: дождаться конца срока переподключения.
    func waitForReconnect() async {
        await reconnectTask?.value
    }
}
