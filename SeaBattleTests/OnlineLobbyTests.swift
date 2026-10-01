//
//  OnlineLobbyTests.swift
//  SeaBattleTests
//
//  R3.3b / R3.3c — вход в «По сети». Game Center подменён сервисом, которым
//  тест управляет руками: когда поиск отвечает, чем и отменён ли он, открыта
//  ли «вечеринка». Проверяется то, что на устройстве не поймать: ответ
//  отменённого поиска, пришедший позже, срок кода, флот, расставленный до
//  прихода соперника, и код, пришедший по ссылке до входа в Game Center.
//

import Foundation
import Testing
@testable import SeaBattle

// MARK: - Подменный сервис

@MainActor
final class FakeOnlineService: OnlineService {
    var online = true
    var signedIn = true
    /// Game Center не открывает «вечеринки» — активность не описана.
    var partiesWork = true
    private(set) var signInCalls = 0
    private(set) var cancelCalls = 0
    /// Все поиски по порядку.
    private(set) var searches: [MatchKind] = []
    /// Открытая сейчас «вечеринка» и все, что открывались.
    private(set) var openParty: InviteCode?
    private(set) var openedParties: [InviteCode] = []
    /// Ответ поиска ждёт здесь: `FoundMatch` не `Sendable`, через продолжение
    /// его не передать, а оба конца и так на главном акторе.
    private var pending: CheckedContinuation<Void, any Error>?
    private var answer: FoundMatch?

    struct NotConfigured: Error {}

    var playerID: String { "me" }
    var playerName: String { "Я" }
    var isSearching: Bool { pending != nil }

    func isOnline() async -> Bool { online }

    func signIn() async -> Bool {
        signInCalls += 1
        return signedIn
    }

    func openParty(_ code: InviteCode) throws -> URL? {
        guard partiesWork else { throw NotConfigured() }
        openParty = code
        openedParties.append(code)
        return URL(string: "https://example.com/\(code.text)")
    }

    func closeParty() {
        openParty = nil
    }

    func findMatch(_ kind: MatchKind) async throws -> FoundMatch {
        searches.append(kind)
        try await withCheckedThrowingContinuation { pending = $0 }
        defer { answer = nil }
        return answer!
    }

    func cancelSearch() {
        cancelCalls += 1
        pending?.resume(throwing: CancellationError())
        pending = nil
    }

    func resolve(_ transport: any NetworkTransport, connected: Bool = true) {
        answer = FoundMatch(transport: transport, connected: connected)
        pending?.resume()
        pending = nil
    }

    /// Game Center сам оборвал поиск.
    func fail() {
        pending?.resume(throwing: URLError(.timedOut))
        pending = nil
    }
}

/// Ждать условие, давая поработать задачам лобби. Не дождались — провал.
@MainActor
private func until(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    for _ in 0..<2000 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(1))
    }
    Issue.record("Условие не наступило", sourceLocation: sourceLocation)
}

// MARK: - Код

@Suite("По сети · код")
struct InviteCodeTests {

    @Test("Набранный код читается с пробелом, дефисом и без них",
          arguments: ["472 913", "472-913", "472913", " 472 913 "])
    func typedVariants(_ typed: String) {
        #expect(InviteCode(typed: typed)?.text == "472-913")
    }

    @Test("Набрать можно только шесть цифр", arguments: ["47291", "4729130", "", "abc def"])
    func typedRejects(_ typed: String) {
        #expect(InviteCode(typed: typed) == nil)
    }

    @Test("Код Game Center из ссылки: буквенный — прописными, цифровой — как есть")
    func partyCodes() {
        #expect(InviteCode(partyCode: "2mp4-9cmf")?.text == "2MP4-9CMF")
        #expect(InviteCode(partyCode: "472-913")?.text == "472-913")
        #expect(InviteCode(partyCode: "12-34")?.text == "12-34")
    }

    @Test("Не формат Game Center — не код: части разной длины, без дефиса, длиннее шести",
          arguments: ["AB-CDE", "ABCD", "1234567-1234567", "A-B", "AB-CD-EF", "АБ-ВГ"])
    func partyRejects(_ code: String) {
        #expect(InviteCode(partyCode: code) == nil)
    }

    @Test("Свой код — шесть цифр через дефис, первая не ноль")
    func randomCodes() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let code = InviteCode.random(using: &generator)
            #expect(code.text.count == 7)
            #expect(code.text.first != "0")
            #expect(InviteCode(typed: code.text) == code)
        }
    }

    @Test("Поле ввода держит шесть цифр и ставит дефис после третьей")
    @MainActor
    func entryFormat() {
        #expect(CodeEntryBlock.format("47") == "47")
        #expect(CodeEntryBlock.format("4729") == "472-9")
        #expect(CodeEntryBlock.format("472 913 5") == "472-913")
        #expect(CodeEntryBlock.format("4a7-2") == "472")
    }
}

// MARK: - Лобби

@MainActor
@Suite("По сети · лобби")
struct OnlineLobbyTests {

    private func lobby(_ service: FakeOnlineService, pacing: OnlinePacing = .instant,
                       joining code: InviteCode? = nil) async -> OnlineLobby {
        let lobby = OnlineLobby(service: service, pacing: pacing, joining: code)
        await lobby.enter()
        return lobby
    }

    // MARK: Вход

    @Test("Без интернета — «Нет соединения», в Game Center даже не входим")
    func offlineFirst() async {
        let service = FakeOnlineService()
        service.online = false
        let lobby = await lobby(service)
        #expect(lobby.stage == .noConnection)
        #expect(service.signInCalls == 0)
    }

    @Test("Не вошли в Game Center — свой экран; «Повторить» после входа ведёт к выбору")
    func signInFailedThenRetry() async {
        let service = FakeOnlineService()
        service.signedIn = false
        let lobby = await lobby(service)
        #expect(lobby.stage == .signInFailed)
        service.signedIn = true
        await lobby.enter()
        #expect(lobby.stage == .choosing)
    }

    // MARK: Случайный соперник

    @Test("Случайный соперник — без «вечеринки», найденный отдаётся оболочке")
    func randomFound() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service)
        var found: (any NetworkTransport)?
        lobby.onFound = { found = $0 }
        lobby.findRandom()
        guard case .searching = lobby.stage else {
            Issue.record("Нет радара: \(lobby.stage)")
            return
        }
        await until { service.isSearching }
        #expect(service.searches == [.random])
        #expect(service.openedParties.isEmpty)
        let transport = LoopbackTransport()
        service.resolve(transport)
        await until { found != nil }
        #expect(found === transport)
    }

    @Test("Поиск оборвался при живой сети — «Никого не нашли», без сети — «Нет соединения»")
    func randomFailure() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service)
        lobby.findRandom()
        await until { service.isSearching }
        service.fail()
        await until { lobby.stage == .failed(.random) }

        lobby.findRandom()
        await until { service.isSearching }
        service.online = false
        service.fail()
        await until { lobby.stage == .noConnection }
    }

    @Test("Отменённый поиск: соперник, пришедший позже, отключается и в партию не попадает")
    func lateResultAfterCancel() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service)
        var foundCount = 0
        lobby.onFound = { _ in foundCount += 1 }
        lobby.findRandom()
        await until { service.isSearching }
        // Game Center отдал соперника в тот же миг, что игрок нажал «Отменить».
        let (late, other) = LoopbackTransport.pair()
        service.resolve(late)
        lobby.cancel()
        #expect(lobby.stage == .choosing)
        // Задача поиска уже отцеплена — ждём сам ответ.
        await until { !late.isLinked }
        #expect(foundCount == 0)
        #expect(!other.isLinked)
    }

    // MARK: Свой код

    @Test("Свой код открывает «вечеринку» со ссылкой; обрыв поиска — ищем заново в ней же")
    func hostRetriesWhileCodeLives() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service, pacing: OnlinePacing(codeLifetime: .seconds(3600),
                                                             retryDelay: .milliseconds(5)))
        lobby.host()
        guard case .hosting(let code, _) = lobby.stage else {
            Issue.record("Нет кода: \(lobby.stage)")
            return
        }
        #expect(service.openParty == code)
        #expect(lobby.partyURL?.absoluteString.hasSuffix(code.text) == true)
        await until { service.isSearching }
        service.fail()
        await until { service.searches.count == 2 }
        #expect(service.searches == [.party, .party])
        #expect(service.openedParties == [code])
        guard case .hosting(let current, _) = lobby.stage else {
            Issue.record("Код пропал: \(lobby.stage)")
            return
        }
        #expect(current == code)
        lobby.cancel()
        #expect(service.openParty == nil)
        #expect(lobby.partyURL == nil)
    }

    @Test("Game Center не открыл «вечеринку» — «Приглашения недоступны», поиска нет")
    func invitesUnavailable() async {
        let service = FakeOnlineService()
        service.partiesWork = false
        let lobby = await lobby(service)
        lobby.host()
        #expect(lobby.stage == .invitesUnavailable)
        #expect(lobby.hostTransport == nil)
        lobby.join(InviteCode(typed: "472913")!)
        #expect(lobby.stage == .invitesUnavailable)
        #expect(service.searches.isEmpty)
    }

    @Test("Код истёк — поиск отменён, «вечеринка» закрыта, оболочку вернули к коду; новый код — тот же транспорт")
    func codeExpires() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service)
        var inviteEnded = false
        lobby.onInviteEnded = { inviteEnded = true }
        lobby.host()
        guard case .hosting(let code, _) = lobby.stage, let transport = lobby.hostTransport else {
            Issue.record("Нет кода")
            return
        }
        await until { lobby.stage == .codeExpired(code) }
        #expect(inviteEnded)
        #expect(service.cancelCalls >= 1)
        #expect(!service.isSearching)
        #expect(service.openParty == nil)

        lobby.renewCode()
        guard case .hosting(let renewed, _) = lobby.stage else {
            Issue.record("Нет нового кода: \(lobby.stage)")
            return
        }
        #expect(lobby.hostTransport === transport)
        #expect(service.openParty == renewed)
        lobby.cancel()
    }

    @Test("Партию приглашающего закрыли на расстановке — поиск и «вечеринка» закрываются")
    func closingTheMatchStopsTheSearch() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service, pacing: OnlinePacing(codeLifetime: .seconds(3600)))
        lobby.host()
        await until { service.isSearching }
        lobby.hostTransport?.disconnect()   // «Меню» в партии на этом транспорте
        #expect(lobby.stage == .choosing)
        #expect(lobby.hostTransport == nil)
        #expect(!service.isSearching)
        #expect(service.openParty == nil)
    }

    @Test("Флот расставлен заранее: соперник пришёл — «Начать» открылась, бой начинается")
    func arrangeAheadThenBattle() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service, pacing: OnlinePacing(codeLifetime: .seconds(3600)))
        var found: (any NetworkTransport)?
        lobby.onFound = { found = $0 }
        lobby.host()
        guard let deferred = lobby.hostTransport else {
            Issue.record("Нет транспорта кода")
            return
        }

        // Партия приглашающего — до соперника, на транспорте кода.
        let host = NetMatch(transport: deferred, statKey: .online,
                            me: NetMatch.hello(name: "Аня", glyph: "sailboat.fill", colorIndex: 0,
                                               accountID: "anya"),
                            records: false)
        host.soundOn = false
        host.start()
        #expect(!host.hasOpponent)

        // Соперник по ту сторону: его приветствие уходит в пустоту.
        let (mine, theirs) = LoopbackTransport.pair()
        let guest = NetMatch(transport: theirs, statKey: .online,
                             me: NetMatch.hello(name: "Борис", glyph: "helm", colorIndex: 8,
                                                accountID: "boris"),
                             records: false)
        guest.soundOn = false
        guest.start()

        await until { service.isSearching }
        service.resolve(mine, connected: true)
        await until { found != nil }
        #expect(found === deferred)
        #expect(deferred.isAttached)
        #expect(host.hasOpponent)
        #expect(guest.hasOpponent)

        host.finishArrangement()
        guest.finishArrangement()
        #expect(host.game.isBattle)
        #expect(guest.game.isBattle)
        #expect(host.isMyTurn != guest.isMyTurn)
    }

    // MARK: Чужой код

    @Test("Набранный код — «вечеринка» с ним; не нашли — «Нет партии с этим кодом», «вечеринка» закрыта")
    func joinFailure() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service)
        lobby.beginEntering()
        lobby.typedCode = "47291"
        #expect(lobby.enteredCode == nil)
        lobby.join()
        #expect(lobby.stage == .entering)

        lobby.typedCode = "472-913"
        lobby.join()
        let code = InviteCode(typed: "472913")!
        await until { service.isSearching }
        #expect(service.openParty == code)
        #expect(service.searches == [.party])
        service.fail()
        await until { lobby.stage == .failed(.join(code)) }
        #expect(service.openParty == nil)
    }

    // MARK: По ссылке

    @Test("Код по ссылке до входа: после входа — сразу присоединяемся, без экрана выбора")
    func linkBeforeSignIn() async {
        let service = FakeOnlineService()
        let code = InviteCode(partyCode: "2MP4-9CMF")!
        let lobby = await lobby(service, joining: code)
        guard case .joining(let joining, _) = lobby.stage else {
            Issue.record("Не присоединились: \(lobby.stage)")
            return
        }
        #expect(joining == code)
        #expect(service.openParty == code)
        lobby.cancel()
    }

    @Test("Код по ссылке, пока свой код на экране: своё приглашение закрывается, идём к другу")
    func linkWhileHosting() async {
        let service = FakeOnlineService()
        let lobby = await lobby(service, pacing: OnlinePacing(codeLifetime: .seconds(3600)))
        lobby.host()
        await until { service.isSearching }
        let code = InviteCode(partyCode: "123-456")!
        lobby.joinFromLink(code)
        guard case .joining(let joining, _) = lobby.stage else {
            Issue.record("Не присоединились: \(lobby.stage)")
            return
        }
        #expect(joining == code)
        #expect(lobby.hostTransport == nil)
        #expect(service.openParty == code)
        lobby.cancel()
    }

    @Test("Код по ссылке на экране «Нет соединения» ждёт входа, а не теряется")
    func linkWhileOffline() async {
        let service = FakeOnlineService()
        service.online = false
        let lobby = await lobby(service)
        let code = InviteCode(partyCode: "123-456")!
        lobby.joinFromLink(code)
        #expect(lobby.stage == .noConnection)
        service.online = true
        await lobby.enter()
        guard case .joining(let joining, _) = lobby.stage else {
            Issue.record("Не присоединились: \(lobby.stage)")
            return
        }
        #expect(joining == code)
        lobby.cancel()
    }
}
