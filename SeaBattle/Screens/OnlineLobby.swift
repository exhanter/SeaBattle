//
//  OnlineLobby.swift
//  Sea Battle — вход в «По сети» без SwiftUI (R3.3b)
//
//  Спека 4.8, кадры `screen5NetSearch`, `screen5NetInvite`, `screen13NoNet`.
//  Всё, что происходит до партии: есть ли интернет, вход в Game Center, три
//  пути к сопернику и срок жизни кода. Сама партия — `NetMatch`, лобби отдаёт
//  ей только транспорт.
//
//  **Код — цифры, а не слово** (решение R3.3): «МОРЕ-47» из кадра не наберёт
//  игрок на другом языке. Шесть цифр — это `GKMatchRequest.playerGroup`:
//  Game Center сводит только тех, кто ищет в одной группе. Случайный соперник
//  ищется в группе 0, коды начинаются со 100 000, поэтому с кодом случайный
//  соперник не придёт.
//
//  **Код живёт 10 минут.** Game Center сам обрывает долгий поиск ошибкой —
//  пока код жив, лобби молча ищет заново; по сроку поиск отменяется, и на
//  экране «Код истёк» с новым кодом.
//
//  **Флот заранее** (4.4): у приглашающего партия создаётся до соперника на
//  `DeferredTransport` — расстановку можно править, «Начать» ждёт подключения.
//

import Foundation
import Observation

// MARK: - Код

/// Код партии: шесть цифр, первая не ноль.
struct InviteCode: Hashable, Sendable {
    static let range = 100_000...999_999

    let value: Int

    init?(value: Int) {
        guard Self.range.contains(value) else { return nil }
        self.value = value
    }

    /// Как его набрали или вставили: пробелы, дефисы и прочее не цифры
    /// отбрасываются — «472 913», «472-913» и «472913» один и тот же код.
    init?(typed: String) {
        let digits = typed.filter(\.isASCIIDigit)
        guard digits.count == 6, let value = Int(digits) else { return nil }
        self.init(value: value)
    }

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> InviteCode {
        InviteCode(value: Int.random(in: range, using: &generator))!
    }

    static func random() -> InviteCode {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// «472 913» — две тройки читаются вслух и не путаются.
    var display: String {
        let digits = String(value)
        return "\(digits.prefix(3)) \(digits.suffix(3))"
    }

    /// Группа подбора в Game Center.
    var playerGroup: Int { value }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

// MARK: - Сервис

/// Найденный соперник. `connected` — связь уже поднята, отдельного сигнала
/// «подключился» от транспорта не будет.
struct FoundMatch {
    let transport: any NetworkTransport
    let connected: Bool
}

/// Game Center и сеть — подменяются в тестах.
@MainActor
protocol OnlineService: AnyObject {
    var playerID: String { get }
    var playerName: String { get }
    func isOnline() async -> Bool
    /// Вошёл — или нет: отказался, Game Center выключен, нет учётной записи.
    func signIn() async -> Bool
    /// Ждёт соперника в группе. Отмена — `cancelSearch()`, тогда ошибка.
    func findMatch(playerGroup: Int) async throws -> FoundMatch
    func cancelSearch()
}

/// Сроки. Параметром — тест проживает срок кода за миллисекунды.
struct OnlinePacing: Sendable {
    var codeLifetime: Duration = .seconds(600)
    /// Пауза перед новым поиском, когда Game Center оборвал прежний.
    var retryDelay: Duration = .seconds(2)

    static let live = OnlinePacing()
    static let instant = OnlinePacing(codeLifetime: .milliseconds(80), retryDelay: .milliseconds(5))
}

// MARK: - Лобби

enum OnlineStage: Equatable, Sendable {
    /// Проверяем интернет.
    case checking
    /// Входим в Game Center: у него может подняться своё окно входа.
    case signingIn
    /// Интернета нет — экран вместо радара (`screen13NoNet`).
    case noConnection
    /// В Game Center не вошли.
    case signInFailed
    /// Выбор: случайный соперник, свой код, чужой код.
    case choosing
    /// Радар (`screen5NetSearch`).
    case searching(since: Date)
    /// Свой код на экране, ждём друга (`screen5NetInvite`).
    case hosting(InviteCode, since: Date)
    case codeExpired(InviteCode)
    /// Набираем код друга.
    case entering
    /// Код набран, ищем того, кто его выдал.
    case joining(InviteCode, since: Date)
    /// Поиск не удался — не отменён, а именно не удался.
    case failed(OnlineSearch)
}

enum OnlineSearch: Equatable, Sendable {
    case random
    case join(InviteCode)
}

@MainActor
@Observable
final class OnlineLobby {

    private(set) var stage: OnlineStage = .checking
    /// Код, который набирают сейчас (`entering`).
    var typedCode = ""

    /// Соперник найден — партию дальше ведёт оболочка. У приглашающего это
    /// всегда `hostTransport`, даже если партия на нём уже создана.
    @ObservationIgnored var onFound: ((any NetworkTransport) -> Void)?
    /// Код истёк или отменён, пока приглашающий был на расстановке: оболочка
    /// возвращает его на экран кода.
    @ObservationIgnored var onInviteEnded: (() -> Void)?

    /// Транспорт партии приглашающего — существует до соперника.
    private(set) var hostTransport: DeferredTransport?

    @ObservationIgnored let service: any OnlineService
    @ObservationIgnored private let pacing: OnlinePacing
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    /// Номер поиска: ответ отменённого поиска приходит позже нового и не
    /// должен его перебить.
    @ObservationIgnored private var searchID = 0

    init(service: any OnlineService, pacing: OnlinePacing = .live) {
        self.service = service
        self.pacing = pacing
    }

    var enteredCode: InviteCode? { InviteCode(typed: typedCode) }

    /// Приглашающий уже расставляет флот, пока ждёт.
    var isHosting: Bool {
        if case .hosting = stage { return true }
        return false
    }

    // MARK: Вход

    /// Открытие экрана и «Повторить»: сначала сеть, потом Game Center — без
    /// сети вход всё равно не пройдёт, а экран «Нет соединения» честнее.
    func enter() async {
        stage = .checking
        guard await service.isOnline() else {
            stage = .noConnection
            return
        }
        stage = .signingIn
        guard await service.signIn() else {
            stage = .signInFailed
            return
        }
        stage = .choosing
    }

    // MARK: Случайный соперник

    func findRandom() {
        stopSearch()
        stage = .searching(since: .now)
        search(group: 0) { [weak self] found in
            self?.onFound?(found.transport)
        } failed: { [weak self] in
            await self?.failOrOffline(.random)
        }
    }

    // MARK: Свой код

    func host() {
        stopSearch()
        let transport = hostTransport ?? makeHostTransport()
        hostTransport = transport
        startHosting(InviteCode.random(), on: transport)
    }

    /// «Новый код» после истечения. Транспорт тот же: флот, расставленный
    /// заранее, остаётся.
    func renewCode() {
        host()
    }

    private func makeHostTransport() -> DeferredTransport {
        let transport = DeferredTransport()
        // Партия закрыта («Меню» на расстановке) — искать больше некого.
        transport.onDisconnect = { [weak self, weak transport] in
            guard let self, let transport, self.hostTransport === transport else { return }
            self.hostTransport = nil
            self.stopSearch()
            self.stage = .choosing
        }
        return transport
    }

    private func startHosting(_ code: InviteCode, on transport: DeferredTransport) {
        stage = .hosting(code, since: .now)
        hostSearch(code, on: transport)
        let id = searchID
        expiryTask = Task { @MainActor [weak self, pacing] in
            try? await Task.sleep(for: pacing.codeLifetime)
            guard !Task.isCancelled, let self, self.searchID == id else { return }
            self.stopSearch()
            self.stage = .codeExpired(code)
            self.onInviteEnded?()
        }
    }

    /// Поиск приглашающего: обрыв поиска Game Center — не конец, пока код жив.
    private func hostSearch(_ code: InviteCode, on transport: DeferredTransport) {
        search(group: code.playerGroup) { [weak self] found in
            guard let self else { return }
            self.expiryTask?.cancel()
            transport.attach(found.transport, connected: found.connected)
            self.onFound?(transport)
        } failed: { [weak self, pacing] in
            try? await Task.sleep(for: pacing.retryDelay)
            guard let self, case .hosting(let current, _) = self.stage, current == code else { return }
            self.hostSearch(code, on: transport)
        }
    }

    // MARK: Чужой код

    func beginEntering() {
        stopSearch()
        typedCode = ""
        stage = .entering
    }

    func join() {
        guard let code = enteredCode else { return }
        join(code)
    }

    /// «Попробовать снова» после неудачи — тот же код.
    func join(_ code: InviteCode) {
        stopSearch()
        stage = .joining(code, since: .now)
        search(group: code.playerGroup) { [weak self] found in
            self?.onFound?(found.transport)
        } failed: { [weak self] in
            await self?.failOrOffline(.join(code))
        }
    }

    // MARK: Отмена

    /// «Отменить поиск» / «Отменить партию» / возврат к выбору. Партия
    /// приглашающего, если он уже расставлял флот, закрывается вместе с кодом.
    func cancel() {
        stopSearch()
        let transport = hostTransport
        hostTransport = nil
        transport?.disconnect()
        stage = .choosing
    }

    /// Уход с экрана совсем.
    func leave() {
        onFound = nil
        onInviteEnded = nil
        cancel()
    }

    // MARK: Поиск

    private func search(group: Int,
                        found: @escaping (FoundMatch) -> Void,
                        failed: @escaping () async -> Void) {
        searchID += 1
        let id = searchID
        searchTask = Task { @MainActor [weak self] in
            guard let service = self?.service else { return }
            do {
                let match = try await service.findMatch(playerGroup: group)
                // Отменили, пока соперник подключался, — он не нужен.
                guard let self, self.searchID == id, !Task.isCancelled else {
                    match.transport.disconnect()
                    return
                }
                found(match)
            } catch {
                guard let self, self.searchID == id, !Task.isCancelled else { return }
                await failed()
            }
        }
    }

    private func stopSearch() {
        let wasSearching = searchTask != nil
        searchID += 1
        searchTask?.cancel()
        searchTask = nil
        expiryTask?.cancel()
        expiryTask = nil
        if wasSearching { service.cancelSearch() }
    }

    /// Поиск оборвался: если пропал интернет — так и сказать.
    private func failOrOffline(_ search: OnlineSearch) async {
        let online = await service.isOnline()
        stage = online ? .failed(search) : .noConnection
    }
}
