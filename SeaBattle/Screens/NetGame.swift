//
//  NetGame.swift
//  Sea Battle — сетевая партия без SwiftUI (R3.3)
//
//  Спека 4.8. Одна сторона партии: своё поле с флотом (здесь и только здесь
//  решается, попал ли соперник), поле соперника, каким его знает игрок по
//  ответам, чей ход, лента «По вам», подсказки, серия партий.
//
//  Чистое значение: сообщение на входе, ответные сообщения на выходе. Радио,
//  звук, таймеры и статистика — в `NetMatch`. Так вся партия, обрыв посреди
//  выстрела и повторная отправка проверяются тестом, который просто носит
//  сообщения между двумя значениями.
//
//  **Кто первый — без отдельного сообщения.** Каждая сторона шлёт в `hello`
//  случайное число; обе считают одно и то же по двум числам. Поэтому и
//  «хозяина» у партии нет: у рядом стоящих устройств, которые нашли друг друга
//  одновременно, его не выбрать.
//

import Foundation

struct NetGame: Equatable, Sendable {

    static let protocolVersion = 2

    enum Stage: Equatable, Sendable {
        case arranging
        case battle
        case over
    }

    /// Чем кончилась партия.
    enum Ending: Equatable, Sendable {
        /// Флот потоплен.
        case fleet
        /// Соперник вышел сам посреди боя — победа ваша (4.8).
        case opponentLeft
        /// Вы сдались.
        case surrendered
    }

    let me: NetHello
    private(set) var opponent: NetHello?
    /// Номер партии в серии. «Ещё партия» переводит на следующий.
    private(set) var round = 0
    private(set) var stage: Stage = .arranging
    private(set) var own = Board()
    private(set) var tracking = Board()
    /// Обводка потопленного промахами — на поле соперника, у себя (4.5).
    let revealsRing: Bool

    private(set) var isReady = false
    /// Номер партии, для которой соперник уже расставил флот. Может обогнать
    /// свой: соперник нажал «Ещё партия» и расставился, пока вы на итогах.
    private(set) var opponentReadyRound: Int?
    /// Соперник уже нажал «Ещё партия» — показать на итогах.
    private(set) var opponentWantsRematch = false
    /// Соперник вышел. После итогов победы это не даёт, но ждать его незачем.
    private(set) var opponentLeft = false

    private(set) var isMyTurn = false
    /// Мой выстрел, на который ещё нет ответа. Пока он есть, второй не уходит.
    private(set) var pendingShot: NetShot?
    private var nextShotSeq = 0
    /// Мой последний ответ сопернику — на случай, если его выстрел придёт ещё раз.
    private var lastAnswer: NetAnswer?

    /// «По вам» — выстрелы соперника за его текущий или последний ход.
    private(set) var incoming: [ShotFeedEntry] = []
    private var nextEntryID = 0
    private(set) var tally = MatchTally()

    private(set) var pendingHint: Int?
    private var nextHintID = 0
    /// Мои ответы на подсказки соперника — повторный запрос получает тот же.
    private var hintAnswers: [Int: Coordinate?] = [:]
    /// Клетки кораблей соперника, открытые мне подсказками.
    private(set) var revealed: Set<Coordinate> = []

    private(set) var winner: Side?
    private(set) var ending: Ending?

    init(me: NetHello, revealsRing: Bool = false) {
        self.me = me
        self.revealsRing = revealsRing
    }

    // MARK: Чтение

    var isSameAccount: Bool { opponent?.accountID == me.accountID }
    var isBattle: Bool { stage == .battle }
    var isOver: Bool { stage == .over }

    /// Можно стрелять: мой ход и прошлый выстрел уже получил ответ.
    var acceptsShot: Bool { stage == .battle && isMyTurn && pendingShot == nil }

    var canRequestHint: Bool { acceptsShot && pendingHint == nil }

    /// Кто стреляет первым в этой партии. Жребий по двум числам, а в серии
    /// первый ход чередуется.
    var iShootFirst: Bool {
        guard let opponent else { return false }
        let coin = ((me.nonce ^ opponent.nonce) &+ UInt64(round)) & 1 == 0
        return coin == amHost
    }

    /// «Хозяин» — сторона с большим числом; при равенстве решают id и имя.
    private var amHost: Bool {
        guard let opponent else { return true }
        return (me.nonce, me.accountID, me.name) > (opponent.nonce, opponent.accountID, opponent.name)
    }

    var hello: NetworkMessage { .hello(me) }

    // MARK: Что пропало при обрыве

    /// После переподключения — всё, что ещё ждёт ответа. Каждое сообщение
    /// безопасно получить дважды.
    func resync() -> [NetworkMessage] {
        var messages: [NetworkMessage] = []
        if stage == .arranging && isReady { messages.append(.ready(round: round)) }
        if let pendingShot { messages.append(.shot(pendingShot)) }
        if let pendingHint { messages.append(.hintRequest(round: round, id: pendingHint)) }
        return messages
    }

    // MARK: Свои действия

    /// «Начать» на расстановке: флот этой партии. Бой начинается, когда
    /// соперник тоже готов.
    mutating func ready(fleet: [ShipPlacement]) -> [NetworkMessage] {
        guard stage == .arranging, !isReady else { return [] }
        own = Board(ships: fleet)
        isReady = true
        beginIfBothReady()
        return [.ready(round: round)]
    }

    /// Выстрел. Повторный по известной клетке правилами разрешён (4.5) —
    /// ответ решит соперник.
    mutating func fire(at coordinate: Coordinate) -> NetworkMessage? {
        guard acceptsShot, coordinate.isOnBoard else { return nil }
        let shot = NetShot(round: round, seq: nextShotSeq, at: coordinate)
        nextShotSeq += 1
        pendingShot = shot
        return .shot(shot)
    }

    /// Подсказка. Баллы списывает `NetMatch` — здесь только очередь запроса.
    mutating func requestHint() -> NetworkMessage? {
        guard canRequestHint else { return nil }
        let id = nextHintID
        nextHintID += 1
        pendingHint = id
        return .hintRequest(round: round, id: id)
    }

    mutating func recordHint(cost: Int) {
        tally.recordHint(cost: cost)
    }

    /// Выход из партии. Посреди боя — сдача; до и после боя — просто уход.
    mutating func leave() -> NetworkMessage {
        if stage == .battle {
            finish(winner: .foe, ending: .surrendered)
        }
        return .quit
    }

    /// «Ещё партия»: следующая партия серии, новый флот, первый ход у другого.
    mutating func rematch() -> NetworkMessage? {
        guard stage == .over else { return nil }
        round += 1
        stage = .arranging
        own = Board()
        tracking = Board()
        isReady = false
        opponentWantsRematch = false
        isMyTurn = false
        pendingShot = nil
        nextShotSeq = 0
        lastAnswer = nil
        incoming = []
        tally = MatchTally()
        pendingHint = nil
        hintAnswers = [:]
        revealed = []
        winner = nil
        ending = nil
        beginIfBothReady()
        return .rematch(round: round)
    }

    // MARK: Сообщения соперника

    /// Что случилось от одного сообщения — для экрана и звука.
    struct Step: Equatable, Sendable {
        var replies: [NetworkMessage] = []
        /// Выстрел лёг на поле: на своё (соперник стрелял) или на его (ответ).
        var shot: Shot?
        /// Соперник заплатил за подсказку — компенсация баллами.
        var compensated = false
        var revealed: Coordinate?
        var began = false
        var opponentQuit = false
        /// У соперника другая версия протокола — играть нельзя.
        var incompatible = false
    }

    struct Shot: Equatable, Sendable {
        let field: Side
        let at: Coordinate
        let outcome: FeedOutcome
        /// Поле до и после — так, как его видит этот игрок.
        let before: Board
        let after: Board
    }

    mutating func receive(_ message: NetworkMessage) -> Step {
        var step = Step()
        switch message {
        case .hello(let hello), .welcome(let hello):
            guard hello.version == Self.protocolVersion else {
                step.incompatible = true
                return step
            }
            opponent = hello
            // На приветствие — ответ: наше могло уйти раньше, чем соперник
            // начал слушать. На ответ не отвечают — петли нет.
            if case .hello = message { step.replies = [.welcome(me)] }
            // Приветствие приходит на каждом подключении — значит, и после
            // обрыва: дошлём то, что могло потеряться.
            step.replies += resync()
            step.began = beginIfBothReady()

        case .ready(let readyRound):
            guard readyRound >= round else { break }
            opponentReadyRound = readyRound
            step.began = beginIfBothReady()

        case .shot(let shot):
            step = defend(shot)

        case .answer(let answer):
            step.shot = apply(answer)

        case .hintRequest(let hintRound, let id):
            guard hintRound == round else { break }
            if let cached = hintAnswers[id] {
                step.replies = [.hintReveal(round: round, id: id, at: cached)]
                break
            }
            let pick = Board.allCoordinates.filter { own[$0] == .ship }.randomElement()
            // `updateValue`: присваивание `nil` через индекс удалило бы ключ.
            hintAnswers.updateValue(pick, forKey: id)
            step.replies = [.hintReveal(round: round, id: id, at: pick)]
            step.compensated = true

        case .hintReveal(let hintRound, let id, let at):
            guard hintRound == round, pendingHint == id else { break }
            pendingHint = nil
            if let at {
                revealed.insert(at)
                step.revealed = at
            }

        case .rematch(let rematchRound):
            if rematchRound > round { opponentWantsRematch = true }

        case .quit:
            opponentLeft = true
            step.opponentQuit = true
            if stage == .battle {
                finish(winner: .you, ending: .opponentLeft)
            }
        }
        return step
    }

    // MARK: Защита — моё поле

    private mutating func defend(_ shot: NetShot) -> Step {
        var step = Step()
        guard shot.round == round else { return step }
        // Этот выстрел уже решён — ответ потерялся по дороге. Тот же ответ,
        // а не второй выстрел.
        if let lastAnswer, lastAnswer.seq == shot.seq {
            step.replies = [.answer(lastAnswer)]
            return step
        }
        let expected = (lastAnswer?.seq ?? -1) + 1
        guard stage == .battle, !isMyTurn, shot.seq == expected else { return step }

        let before = own
        let result = own.apply(shotAt: shot.at)
        guard let outcome = FeedOutcome(result) else { return step }

        incoming.append(ShotFeedEntry(id: nextEntryID, coordinate: shot.at, outcome: outcome))
        nextEntryID += 1

        var sunkCells: [Coordinate]?
        if case .sunk(let ship) = result { sunkCells = ship.cells }
        let lost = own.isFleetDestroyed
        let answer = NetAnswer(round: round, seq: shot.seq, at: shot.at, outcome: outcome,
                               sunkShip: sunkCells, defenderLost: lost)
        lastAnswer = answer
        step.replies = [.answer(answer)]
        step.shot = Shot(field: .you, at: shot.at, outcome: outcome, before: before, after: own)

        if lost {
            finish(winner: .foe, ending: .fleet)
        } else if !result.keepsTurn {
            isMyTurn = true
        }
        return step
    }

    // MARK: Атака — поле соперника

    private mutating func apply(_ answer: NetAnswer) -> Shot? {
        guard answer.round == round, let pending = pendingShot, pending.seq == answer.seq else {
            return nil
        }
        pendingShot = nil
        let before = tracking
        switch answer.outcome {
        case .miss:
            tracking.mark(.miss, at: answer.at)
        case .hit:
            tracking.mark(.hit, at: answer.at)
        case .sunk:
            let cells = answer.sunkShip ?? [answer.at]
            for cell in cells { tracking.mark(.sunk, at: cell) }
            if revealsRing {
                let ring = Set(cells.flatMap(\.neighbours)).subtracting(cells)
                for cell in ring where tracking[cell] == .water { tracking.mark(.miss, at: cell) }
            }
        case .repeatHit, .repeatMiss:
            break
        }
        tally.record(outcome: answer.outcome)

        if answer.defenderLost {
            finish(winner: .you, ending: .fleet)
        } else if !answer.outcome.isDamage {
            // Ход уходит сопернику: лента «По вам» начинается заново.
            isMyTurn = false
            incoming = []
        }
        return Shot(field: .foe, at: answer.at, outcome: answer.outcome,
                    before: before, after: tracking)
    }

    // MARK: Начало и конец

    @discardableResult
    private mutating func beginIfBothReady() -> Bool {
        guard stage == .arranging, isReady, opponentReadyRound == round, opponent != nil else {
            return false
        }
        stage = .battle
        isMyTurn = iShootFirst
        return true
    }

    private mutating func finish(winner: Side, ending: Ending) {
        stage = .over
        isMyTurn = false
        pendingShot = nil
        pendingHint = nil
        self.winner = winner
        self.ending = ending
    }
}
