//
//  OnlineLobby.swift
//  Sea Battle — вход в «По сети» без SwiftUI (R3.3b, R3.3c)
//
//  Спека 4.8, кадры `screen5NetSearch`, `screen5NetInvite`, `screen13NoNet`.
//  Всё, что происходит до партии: есть ли интернет, вход в Game Center, три
//  пути к сопернику и срок жизни кода. Сама партия — `NetMatch`, лобби отдаёт
//  ей только транспорт.
//
//  **«По сети» — только iOS 26+** (решение заказчика 01.10): на iOS 18 Pro не
//  продаётся, и этот экран не открывается. Поэтому код приглашения — код
//  «вечеринки» Game Center (`GKGameActivity`): к нему прилагается ссылка, по
//  которой друг попадает прямо в партию, а сама партия видна в приложении
//  «Игры». Game Center принимает и коды из одних цифр — две равные части через
//  дефис, — поэтому код по-прежнему шесть цифр («472-913»): его легко
//  продиктовать и набрать на цифровой клавиатуре (решение R3.3 — не слово).
//
//  **Код живёт 10 минут** — наше правило, не Game Center: пока код жив, лобби
//  молча ищет заново, когда Game Center обрывает долгий поиск; по сроку —
//  «Код истёк» и новый код.
//
//  **Флот заранее** (4.4): у приглашающего партия создаётся до соперника на
//  `DeferredTransport` — расстановку можно править, «Начать» ждёт подключения.
//

import Foundation
import Observation

// MARK: - Код

/// Код «вечеринки» Game Center. Свои коды — шесть цифр, «472-913»; чужой,
/// пришедший по ссылке или из приложения «Игры», может быть и буквенным
/// («2MP4-9CMF») — Game Center выдаёт такие сам.
struct InviteCode: Hashable, Sendable {
    /// Как код показан и как его понимает Game Center: две равные части через
    /// дефис, прописными.
    let text: String

    /// Код в формате Game Center: две равные части по 2–6 знаков через дефис,
    /// обе из цифр или обе из букв и цифр (заголовок `GKGameActivity`,
    /// `isValidPartyCode`). Окончательно код проверяет Game Center — здесь
    /// отсекается явный мусор.
    init?(partyCode: String) {
        let upper = partyCode.trimmingCharacters(in: .whitespaces).uppercased()
        let parts = upper.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == parts[1].count,
              (2...6).contains(parts[0].count),
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && ($0.isNumber || $0.isLetter) } })
        else { return nil }
        text = upper
    }

    /// Набранный руками: только шесть цифр, пробелы, дефисы и прочее
    /// отбрасываются — «472 913», «472-913» и «472913» один и тот же код.
    init?(typed: String) {
        let digits = typed.filter { $0.isASCII && $0.isNumber }
        guard digits.count == 6 else { return nil }
        self.init(partyCode: "\(digits.prefix(3))-\(digits.suffix(3))")
    }

    /// Шесть цифр, первая не ноль — чтобы код не начинался с «0», который
    /// легко потерять, диктуя.
    static func random<G: RandomNumberGenerator>(using generator: inout G) -> InviteCode {
        InviteCode(typed: String(Int.random(in: 100_000...999_999, using: &generator)))!
    }

    static func random() -> InviteCode {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }
}

// MARK: - Сервис

/// Найденный соперник. `connected` — связь уже поднята, отдельного сигнала
/// «подключился» от транспорта не будет.
struct FoundMatch {
    let transport: any NetworkTransport
    let connected: Bool
}

/// Кого ищем: случайного соперника или того, кто в той же «вечеринке».
enum MatchKind: Equatable, Sendable {
    case random
    case party
}

/// Game Center и сеть — подменяются в тестах.
@MainActor
protocol OnlineService: AnyObject {
    var playerID: String { get }
    var playerName: String { get }
    func isOnline() async -> Bool
    /// Вошёл — или нет: отказался, Game Center выключен, нет учётной записи.
    func signIn() async -> Bool
    /// Открыть «вечеринку» с этим кодом — свою или чужую. Возвращает ссылку
    /// для «Поделиться». Ошибка — приглашения недоступны (активность не
    /// описана в App Store Connect, код не принят).
    func openParty(_ code: InviteCode) throws -> URL?
    /// Закрыть открытую «вечеринку».
    func closeParty()
    /// Ждёт соперника. Отмена — `cancelSearch()`, тогда ошибка.
    func findMatch(_ kind: MatchKind) async throws -> FoundMatch
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
    /// Код набран или пришёл по ссылке, ищем того, кто его выдал.
    case joining(InviteCode, since: Date)
    /// Поиск не удался — не отменён, а именно не удался.
    case failed(OnlineSearch)
    /// Game Center не открыл «вечеринку»: приглашать по коду сейчас нельзя.
    case invitesUnavailable
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
    /// Ссылка на свою «вечеринку» — для «Поделиться».
    private(set) var partyURL: URL?

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
    /// Код из ссылки, пришедшей до входа: после входа — сразу к нему.
    @ObservationIgnored private var pendingJoin: InviteCode?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    /// Номер поиска: ответ отменённого поиска приходит позже нового и не
    /// должен его перебить.
    @ObservationIgnored private var searchID = 0
    @ObservationIgnored private var partyIsOpen = false

    init(service: any OnlineService, pacing: OnlinePacing = .live, joining code: InviteCode? = nil) {
        self.service = service
        self.pacing = pacing
        self.pendingJoin = code
    }

    var enteredCode: InviteCode? { InviteCode(typed: typedCode) }

    // MARK: Вход

    /// Открытие экрана и «Повторить»: сначала сеть, потом Game Center — без
    /// сети вход всё равно не пройдёт, а экран «Нет соединения» честнее.
    /// Пришли по ссылке — после входа сразу присоединяемся.
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
        if let code = pendingJoin {
            pendingJoin = nil
            join(code)
        }
    }

    /// Ссылка пришла, когда экран уже открыт.
    func joinFromLink(_ code: InviteCode) {
        switch stage {
        case .checking, .signingIn, .noConnection, .signInFailed:
            // Вход ещё не прошёл — присоединимся после него.
            pendingJoin = code
        default:
            cancel()
            join(code)
        }
    }

    // MARK: Случайный соперник

    func findRandom() {
        stopSearch()
        stage = .searching(since: .now)
        search(.random) { [weak self] found in
            self?.onFound?(found.transport)
        } failed: { [weak self] in
            await self?.failOrOffline(.random)
        }
    }

    // MARK: Свой код

    func host() {
        stopSearch()
        let code = InviteCode.random()
        guard open(code) else {
            stage = .invitesUnavailable
            return
        }
        let transport = hostTransport ?? makeHostTransport()
        hostTransport = transport
        startHosting(code, on: transport)
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
            self.closeParty()
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
            self.closeParty()
            self.stage = .codeExpired(code)
            self.onInviteEnded?()
        }
    }

    /// Поиск приглашающего: обрыв поиска Game Center — не конец, пока код жив.
    private func hostSearch(_ code: InviteCode, on transport: DeferredTransport) {
        search(.party) { [weak self] found in
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
        closeParty()
        typedCode = ""
        stage = .entering
    }

    func join() {
        guard let code = enteredCode else { return }
        join(code)
    }

    /// Набранный код, код из ссылки и «Попробовать снова» после неудачи.
    func join(_ code: InviteCode) {
        stopSearch()
        guard open(code) else {
            stage = .invitesUnavailable
            return
        }
        stage = .joining(code, since: .now)
        search(.party) { [weak self] found in
            self?.onFound?(found.transport)
        } failed: { [weak self] in
            self?.closeParty()
            await self?.failOrOffline(.join(code))
        }
    }

    // MARK: Отмена

    /// «Отменить поиск» / «Отменить партию» / возврат к выбору. Партия
    /// приглашающего, если он уже расставлял флот, закрывается вместе с кодом.
    func cancel() {
        stopSearch()
        closeParty()
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

    // MARK: «Вечеринка»

    /// Одна открытая «вечеринка» за раз: новый код закрывает прежний.
    private func open(_ code: InviteCode) -> Bool {
        closeParty()
        do {
            partyURL = try service.openParty(code)
            partyIsOpen = true
            return true
        } catch {
            return false
        }
    }

    private func closeParty() {
        guard partyIsOpen else { return }
        partyIsOpen = false
        partyURL = nil
        service.closeParty()
    }

    // MARK: Поиск

    private func search(_ kind: MatchKind,
                        found: @escaping (FoundMatch) -> Void,
                        failed: @escaping () async -> Void) {
        searchID += 1
        let id = searchID
        searchTask = Task { @MainActor [weak self] in
            guard let service = self?.service else { return }
            do {
                let match = try await service.findMatch(kind)
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
