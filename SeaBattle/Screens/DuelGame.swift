//
//  DuelGame.swift
//  Sea Battle — вдвоём на устройстве без SwiftUI (R3.2)
//
//  Спека 4.7. Два человека по очереди держат одно устройство. Правила
//  выстрела — ядро (`Board.apply`), здесь то, чего ядро не знает: кто сейчас
//  держит устройство, кому его передают, код, номер хода, лента «По вам» и
//  счёт серии.
//
//  Главное правило режима — **поля видит только тот, кто открыл слой
//  передачи**. Поэтому держатель устройства хранится явно (`holder`), и после
//  продолжения партии из меню он неизвестен: слой встаёт снова, и код
//  спрашивается даже у того, кто держал устройство последним.
//
//  Вынесено из экрана, как `PaperGame`: правил тут больше, чем кажется, и
//  каждое проверяется тестом, а не нажатиями.
//

import Foundation

// MARK: - Игроки и настройка

/// Игрок серии — то, что выбрано в `PlayerCard`: имя, значок и цвет.
struct DuelPlayer: Codable, Equatable, Sendable {
    var name: String
    var glyph: String
    var colorIndex: Int
}

/// «Первый ход» на экране настройки (4.7): жребий или один из игроков.
enum DuelFirstMove: Hashable, Codable, Sendable {
    case coinToss
    case player(Int)

    /// Кто стреляет первым. Жребий бросается на каждую партию серии заново.
    func resolve<G: RandomNumberGenerator>(using generator: inout G) -> Int {
        switch self {
        case .coinToss: Int.random(in: 0...1, using: &generator)
        case .player(let index): index
        }
    }
}

/// Экран настройки. Живёт в оболочке: уход на расстановку и возврат не
/// должны стирать то, что игроки уже набрали.
struct DuelSetup: Equatable, Sendable {
    /// Значки и цвета по умолчанию — как в кадре `screen4TwoSetup`: латунный
    /// парусник и лазурный штурвал (якоря в SF Symbols нет), то есть сразу разные.
    var players = [DuelPlayer(name: "", glyph: "sailboat.fill", colorIndex: 0),
                   DuelPlayer(name: "", glyph: "helm", colorIndex: 8)]
    /// «Закрывать экран кодом» — по умолчанию выключено (4.7).
    var locksWithCode = false
    var firstMove: DuelFirstMove = .coinToss

    /// Пустое имя — «Игрок 1» / «Игрок 2»: нетерпеливые могут просто нажать
    /// кнопку, ничего не набирая.
    static func displayName(_ typed: String, index: Int) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(game: "Player \(index + 1)") : trimmed
    }

    func displayName(_ index: Int) -> String {
        Self.displayName(players[index].name, index: index)
    }

    /// Два одинаковых имени не различить ни на слое передачи, ни в счёте серии.
    var namesDiffer: Bool {
        displayName(0).caseInsensitiveCompare(displayName(1)) != .orderedSame
    }

    /// Владелец устройства (R4.4) садится в первую карточку — только в пустую:
    /// набранное руками не перетирается. Совпали значок или цвет со вторым
    /// игроком — второму достаётся другой, иначе на слое передачи их не
    /// различить.
    mutating func seat(_ own: OwnPlayer) {
        let name = own.trimmedName
        guard !name.isEmpty,
              players[0].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.caseInsensitiveCompare(players[1].name.trimmingCharacters(in: .whitespacesAndNewlines))
                != .orderedSame
        else { return }
        players[0] = DuelPlayer(name: name, glyph: own.glyph, colorIndex: own.colorIndex)
        if players[1].glyph == own.glyph {
            players[1].glyph = PlayerAvatar.glyphs.first { $0 != own.glyph } ?? players[1].glyph
        }
        if players[1].colorIndex == own.colorIndex {
            players[1].colorIndex = PlayerAvatar.colors.indices.first { $0 != own.colorIndex } ?? 0
        }
    }

    /// Игроки с именами, подставленными вместо пустых.
    var resolvedPlayers: [DuelPlayer] {
        players.indices.map { index in
            var player = players[index]
            player.name = displayName(index)
            return player
        }
    }
}

// MARK: - Партия

struct DuelGame: Codable, Equatable, Sendable {

    enum Stage: Codable, Equatable, Sendable {
        /// Игрок расставляет флот. Первым всегда первый игрок: устройство
        /// у того, кто заполнял настройку.
        case arranging(Int)
        case battle
    }

    /// Что спросить на слое передачи.
    enum CodeStep: Equatable, Sendable {
        /// Код выключен или устройство не меняло рук.
        case none
        /// Кода у игрока ещё нет — придумать (при первой передаче ему).
        case create
        case enter
    }

    let players: [DuelPlayer]
    let locksWithCode: Bool
    /// «Обводка потопленного промахами» — настройка, на партию запоминается
    /// при старте, как в игре на бумаге.
    let revealsRing: Bool
    let firstMove: DuelFirstMove
    /// Кто стреляет первым — решено при создании партии (жребий тоже).
    let firstShooter: Int

    /// Хэши кодов, `nil` — ещё не придуман. Живут всю серию.
    private(set) var codes: [String?]
    private(set) var stage: Stage
    /// Поле игрока `i` — с его флотом.
    private(set) var boards: [Board]
    private(set) var attacker: Int
    /// Номер хода — есть только на слое передачи (2.5). Ход — это очередь
    /// одного игрока, от передачи до передачи.
    private(set) var turn = 0
    /// Кто сейчас держит устройство и видит поля. `nil` — неизвестно (партию
    /// продолжили из меню): открыть её может только код.
    private(set) var holder: Int?
    /// Кому передают устройство — слой передачи на экране.
    private(set) var handoff: Int?
    /// «По вам за этот раунд» — выстрелы по полю игрока `i` за последний ход
    /// соперника (2.8).
    private(set) var incoming: [[ShotFeedEntry]] = [[], []]
    private(set) var tallies = [MatchTally(), MatchTally()]
    private(set) var winner: Int?
    /// Счёт серии (4.9): живёт, пока играют «Ещё партию», и умирает с ней.
    private(set) var series: [Int]
    private var nextShotID = 0

    init(players: [DuelPlayer],
         locksWithCode: Bool,
         revealsRing: Bool,
         firstMove: DuelFirstMove,
         firstShooter: Int,
         holder: Int? = 0,
         codes: [String?] = [nil, nil],
         series: [Int] = [0, 0]) {
        self.players = players
        self.locksWithCode = locksWithCode
        self.revealsRing = revealsRing
        self.firstMove = firstMove
        self.firstShooter = firstShooter
        self.codes = codes
        self.series = series
        self.holder = holder
        self.stage = .arranging(0)
        self.boards = [Board(), Board()]
        self.attacker = firstShooter
        handOver(to: 0)
    }

    init<G: RandomNumberGenerator>(setup: DuelSetup, revealsRing: Bool, using generator: inout G) {
        self.init(players: setup.resolvedPlayers,
                  locksWithCode: setup.locksWithCode,
                  revealsRing: revealsRing,
                  firstMove: setup.firstMove,
                  firstShooter: setup.firstMove.resolve(using: &generator))
    }

    init(setup: DuelSetup, revealsRing: Bool) {
        var generator = SystemRandomNumberGenerator()
        self.init(setup: setup, revealsRing: revealsRing, using: &generator)
    }

    // MARK: Чтение

    var defender: Int { 1 - attacker }

    /// Чья сейчас очередь: расставлять или стрелять.
    var current: Int {
        switch stage {
        case .arranging(let player): player
        case .battle: attacker
        }
    }

    /// Чьими глазами нарисован экран под слоем: держатель, а пока он
    /// неизвестен — тот, чья очередь (экран всё равно закрыт слоем).
    var viewer: Int { holder ?? current }

    var isOver: Bool { winner != nil }

    var isBattle: Bool { stage == .battle }

    /// Жребием ли выбран первый ход — слой передачи первого хода говорит об этом.
    var isCoinToss: Bool { firstMove == .coinToss }

    var codeStep: CodeStep {
        guard let target = handoff, locksWithCode else { return .none }
        if codes[target] == nil { return .create }
        return target == holder ? .none : .enter
    }

    /// Можно ли сейчас стрелять: бой, слоя нет, устройство у стреляющего.
    var acceptsShot: Bool {
        isBattle && !isOver && handoff == nil && holder == attacker
    }

    // MARK: Передача устройства

    /// Слой нужен, когда устройство меняет руки или игроку пора придумать
    /// код. Начало боя объявляется всегда — `announce`: игроки должны
    /// узнать, кто стреляет первым, даже если устройство уже у него.
    private mutating func handOver(to player: Int, announce: Bool = false) {
        let needsCode = locksWithCode && codes[player] == nil
        handoff = announce || needsCode || player != holder ? player : nil
    }

    /// Открыть слой. Код проверяется только когда он нужен (`codeStep`);
    /// при `.create` переданный код запоминается. Неверный код — `false`.
    @discardableResult
    mutating func open(with code: String? = nil) -> Bool {
        guard let target = handoff else { return false }
        switch codeStep {
        case .none:
            break
        case .create:
            guard let code, Self.isValid(code) else { return false }
            codes[target] = ProfileStore.hash(pin: code)
        case .enter:
            guard let code, ProfileStore.hash(pin: code) == codes[target] else { return false }
        }
        holder = target
        handoff = nil
        return true
    }

    /// Код — ровно четыре цифры (кадр `screen4Handoff`).
    static let codeLength = 4

    static func isValid(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy(\.isASCII) && code.allSatisfy(\.isNumber)
    }

    /// Партию продолжили из меню — или вышли в меню посреди неё. Кто теперь
    /// держит устройство, неизвестно, поэтому слой встаёт снова и спрашивает
    /// код даже у того, кто держал его последним.
    mutating func relock() {
        guard !isOver else { return }
        handoff = handoff ?? current
        holder = nil
    }

    // MARK: Расстановка

    mutating func finishArrangement(_ ships: [ShipPlacement]) {
        guard case .arranging(let player) = stage, handoff == nil,
              holder == player, FleetLayout.conflicts(in: ships).isEmpty else { return }
        boards[player] = Board(ships: ships)
        if player == 0 {
            stage = .arranging(1)
            handOver(to: 1)
        } else {
            stage = .battle
            attacker = firstShooter
            turn = 1
            handOver(to: attacker, announce: true)
        }
    }

    // MARK: Выстрел

    /// Выстрел держателя по полю соперника. Попадание оставляет ход, промах и
    /// повторный выстрел отдают его (4.5) — и устройство уходит другому.
    @discardableResult
    mutating func fire(at coordinate: Coordinate) -> Board.ShotResult? {
        guard acceptsShot, coordinate.isOnBoard else { return nil }
        let target = defender
        let result = boards[target].apply(shotAt: coordinate)
        guard let outcome = FeedOutcome(result) else { return nil }
        if case .sunk(let ship) = result, revealsRing {
            boards[target].revealRing(around: ship)
        }
        tallies[attacker].record(result)
        incoming[target].append(ShotFeedEntry(id: nextShotID, coordinate: coordinate, outcome: outcome))
        nextShotID += 1

        if boards[target].isFleetDestroyed {
            winner = attacker
            series[attacker] += 1
        } else if !result.keepsTurn {
            attacker = target
            turn += 1
            // Новый ход — новая лента у того, по кому теперь будут стрелять.
            incoming[defender] = []
            handOver(to: attacker)
        }
        return result
    }

    // MARK: Серия

    /// «Ещё партия»: те же игроки, коды и счёт серии, новые поля. Устройство
    /// остаётся у того, кто держал его на итогах.
    func rematch<G: RandomNumberGenerator>(using generator: inout G) -> DuelGame {
        DuelGame(players: players,
                 locksWithCode: locksWithCode,
                 revealsRing: revealsRing,
                 firstMove: firstMove,
                 firstShooter: firstMove.resolve(using: &generator),
                 holder: holder,
                 codes: codes,
                 series: series)
    }

    func rematch() -> DuelGame {
        var generator = SystemRandomNumberGenerator()
        return rematch(using: &generator)
    }
}
