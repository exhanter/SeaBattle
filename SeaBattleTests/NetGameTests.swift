//
//  NetGameTests.swift
//  SeaBattleTests
//
//  R3.3 — сетевая партия. Проверяется то, что на двух устройствах не
//  поймать: ход, который обе стороны считают своим, выстрел, решённый дважды
//  после обрыва, победа при обрыве связи, серия, где одна сторона обогнала
//  другую.
//

import Foundation
import Testing
@testable import SeaBattle

// MARK: - Правила без транспорта

@MainActor
@Suite("Сетевая партия · правила")
struct NetGameTests {

    private func hello(_ name: String, nonce: UInt64, account: String = "same") -> NetHello {
        NetHello(name: name, glyph: "sailboat.fill", colorIndex: 0, accountID: account,
                 nonce: nonce, version: NetGame.protocolVersion)
    }

    /// Две стороны после приветствия и расстановки — бой начат. Сообщения
    /// носятся руками: так видно каждое.
    private func battle(nonceA: UInt64 = 7, nonceB: UInt64 = 12) -> (NetGame, NetGame) {
        var a = NetGame(me: hello("A", nonce: nonceA))
        var b = NetGame(me: hello("B", nonce: nonceB))
        _ = a.receive(b.hello)
        _ = b.receive(a.hello)
        for message in a.ready(fleet: FleetLayout.canonicalLayout()) { _ = b.receive(message) }
        for message in b.ready(fleet: FleetLayout.canonicalLayout()) { _ = a.receive(message) }
        return (a, b)
    }

    /// Выстрел и ответ целиком.
    private func exchange(_ shooter: inout NetGame, _ target: inout NetGame, at cell: Coordinate) {
        guard let shot = shooter.fire(at: cell) else { return }
        for reply in target.receive(shot).replies { _ = shooter.receive(reply) }
    }

    private var water: Coordinate {
        Board.allCoordinates.first { Board(ships: FleetLayout.canonicalLayout())[$0] == .water }!
    }

    private var hull: Coordinate {
        FleetLayout.canonicalLayout().first { $0.length == 4 }!.cells[0]
    }

    @Test("Бой начинается у обоих, и ход ровно у одного")
    func exactlyOneSideShoots() {
        for nonce in [UInt64(1), 2, 3, 99] {
            let (a, b) = battle(nonceA: nonce, nonceB: 50)
            #expect(a.isBattle && b.isBattle)
            #expect(a.isMyTurn != b.isMyTurn)
        }
    }

    @Test("Первый ход в серии чередуется")
    func firstMoveAlternates() {
        var (a, b) = battle()
        let first = a.isMyTurn
        // Сдача кончает партию у обоих.
        _ = b.receive(a.leave())
        for message in [a.rematch(), b.rematch()].compactMap({ $0 }) {
            _ = a.receive(message)
            _ = b.receive(message)
        }
        for message in a.ready(fleet: FleetLayout.canonicalLayout()) { _ = b.receive(message) }
        for message in b.ready(fleet: FleetLayout.canonicalLayout()) { _ = a.receive(message) }
        #expect(a.isBattle && b.isBattle)
        #expect(a.isMyTurn == !first)
        #expect(a.isMyTurn != b.isMyTurn)
    }

    @Test("Попадание оставляет ход, промах отдаёт его, лента у защитника")
    func hitKeepsMissPasses() {
        var (a, b) = battle()
        if !a.isMyTurn { swap(&a, &b) }

        exchange(&a, &b, at: hull)
        #expect(a.isMyTurn && !b.isMyTurn)
        #expect(a.tracking[hull] == .hit)
        #expect(b.own[hull] == .hit)
        #expect(b.incoming.map(\.outcome) == [.hit])

        exchange(&a, &b, at: water)
        #expect(!a.isMyTurn && b.isMyTurn)
        #expect(a.tracking[water] == .miss)
        #expect(b.incoming.map(\.outcome) == [.hit, .miss])
        #expect(a.tally.shots == 2 && a.tally.hits == 1)
    }

    @Test("Потопленный корабль открывается целиком, обводка — по настройке стрелка")
    func sinkingRevealsShip() {
        var a = NetGame(me: hello("A", nonce: 7), revealsRing: true)
        var b = NetGame(me: hello("B", nonce: 12))
        _ = a.receive(b.hello)
        _ = b.receive(a.hello)
        for message in a.ready(fleet: FleetLayout.canonicalLayout()) { _ = b.receive(message) }
        for message in b.ready(fleet: FleetLayout.canonicalLayout()) { _ = a.receive(message) }
        if !a.isMyTurn {
            exchange(&b, &a, at: water)
        }
        let ship = FleetLayout.canonicalLayout().first { $0.length == 3 }!
        for cell in ship.cells { exchange(&a, &b, at: cell) }

        #expect(a.tracking.sunkShipCount == 1)
        #expect(ship.cells.allSatisfy { a.tracking[$0] == .sunk })
        #expect(ship.ring.filter(\.isOnBoard).allSatisfy { a.tracking[$0] == .miss })
        #expect(a.tracking.ships.isEmpty, "Флот соперника по сети не приходит")
    }

    @Test("Повторный выстрел разрешён: ответ «повторный», ход уходит")
    func repeatedShotPassesTurn() {
        var (a, b) = battle()
        if !a.isMyTurn { swap(&a, &b) }
        exchange(&a, &b, at: hull)
        exchange(&a, &b, at: hull)
        #expect(!a.isMyTurn && b.isMyTurn)
        #expect(b.incoming.last?.outcome == .repeatHit)
        #expect(b.own[hull] == .hit)
    }

    @Test("Потерянный ответ: выстрел дослан, но решён один раз")
    func lostAnswerIsResentNotRefired() {
        var (a, b) = battle()
        if !a.isMyTurn { swap(&a, &b) }
        let shot = a.fire(at: water)!
        let first = b.receive(shot)          // ответ ушёл и потерялся
        #expect(b.isMyTurn)
        #expect(a.fire(at: hull) == nil, "Пока нет ответа, второй выстрел не уходит")

        let resent = a.resync()
        #expect(resent == [shot])
        let second = b.receive(shot)
        #expect(second.replies == first.replies, "Тот же ответ, а не второй выстрел")
        #expect(second.shot == nil)
        #expect(b.incoming.count == 1)

        for reply in second.replies { _ = a.receive(reply) }
        #expect(a.tracking[water] == .miss && !a.isMyTurn)
        // Дубль ответа ничего не меняет.
        for reply in first.replies { #expect(a.receive(reply).shot == nil) }
        #expect(a.tally.shots == 1)
    }

    @Test("Потерянный выстрел: дослан и решён")
    func lostShotIsResent() {
        var (a, b) = battle()
        if !a.isMyTurn { swap(&a, &b) }
        _ = a.fire(at: hull)                 // не дошёл
        for message in a.resync() {
            for reply in b.receive(message).replies { _ = a.receive(reply) }
        }
        #expect(a.tracking[hull] == .hit && a.isMyTurn)
    }

    @Test("Готовность, потерянная до боя, досылается при новом приветствии")
    func readyIsResent() {
        var a = NetGame(me: hello("A", nonce: 7))
        var b = NetGame(me: hello("B", nonce: 12))
        _ = a.ready(fleet: FleetLayout.canonicalLayout())   // до подключения
        _ = b.ready(fleet: FleetLayout.canonicalLayout())
        // Приветствие A дошло, приветствие B потерялось: ответа хватает.
        for message in b.receive(a.hello).replies {
            for back in a.receive(message).replies { _ = b.receive(back) }
        }
        #expect(a.isBattle && b.isBattle)
    }

    @Test("Серия: соперник расставился раньше, чем вы нажали «Ещё партию»")
    func opponentAheadInSeries() {
        var (a, b) = battle()
        _ = b.receive(a.leave())
        #expect(a.isOver && b.isOver)
        for message in [a.rematch()!] + a.ready(fleet: FleetLayout.canonicalLayout()) {
            _ = b.receive(message)
        }
        #expect(b.isOver, "На итогах чужая готовность партию не начинает")
        #expect(b.opponentWantsRematch)
        for message in [b.rematch()!] + b.ready(fleet: FleetLayout.canonicalLayout()) {
            _ = a.receive(message)
        }
        #expect(a.isBattle && b.isBattle)
        #expect(a.round == 1 && b.round == 1)
    }

    @Test("Выход соперника посреди боя — победа, до боя — нет")
    func quitCountsOnlyInBattle() {
        var (a, b) = battle()
        _ = b.receive(a.leave())
        #expect(a.winner == .foe && a.ending == .surrendered)
        #expect(b.winner == .you && b.ending == .opponentLeft)

        var c = NetGame(me: hello("C", nonce: 1))
        _ = c.receive(.quit)
        #expect(c.winner == nil && c.opponentLeft)
    }

    @Test("Другая версия протокола — играть нельзя")
    func versionMismatch() {
        var a = NetGame(me: hello("A", nonce: 1))
        var old = hello("B", nonce: 2)
        old.version = 1
        #expect(a.receive(.hello(old)).incompatible)
        #expect(a.opponent == nil)
    }

    @Test("Подсказка открывает непотопленную клетку; повторный запрос — тот же ответ")
    func hintRevealsShipCell() throws {
        var (a, b) = battle()
        if !a.isMyTurn { swap(&a, &b) }
        let request = a.requestHint()!
        #expect(a.requestHint() == nil, "Второй запрос не уходит, пока нет ответа")
        let step = b.receive(request)
        #expect(step.compensated)
        let again = b.receive(request)
        #expect(!again.compensated && again.replies == step.replies)
        for reply in step.replies { _ = a.receive(reply) }
        let cell = try #require(a.revealed.first)
        #expect(b.own[cell] == .ship)
        #expect(a.pendingHint == nil)
    }
}

// MARK: - Партия с транспортом

@MainActor
@Suite("Сетевая партия · связь")
struct NetMatchTests {

    private func pair(sameAccount: Bool = true) -> (NetMatch, NetMatch, LoopbackTransport) {
        let (a, b) = LoopbackTransport.pair()
        let one = NetMatch(transport: a, statKey: .nearby,
                           me: NetMatch.hello(name: "A", glyph: "a", colorIndex: 0, accountID: "one"),
                           pacing: .instant, records: false)
        let two = NetMatch(transport: b, statKey: .nearby,
                           me: NetMatch.hello(name: "B", glyph: "b", colorIndex: 1,
                                              accountID: sameAccount ? "one" : "two"),
                           pacing: .instant, records: false)
        for match in [one, two] {
            match.soundOn = false
            match.editor = FleetEditor(ships: FleetLayout.canonicalLayout())
            match.start()
            match.finishArrangement()
        }
        return one.isMyTurn ? (one, two, a) : (two, one, b)
    }

    @Test("Целая партия: обе стороны согласны, итог готов у обеих")
    func wholeMatch() {
        let (shooter, target, _) = pair()
        for cell in FleetLayout.canonicalLayout().flatMap(\.cells) { shooter.tap(cell) }
        #expect(shooter.result?.didWin == true)
        #expect(target.result?.didWin == false)
        #expect(shooter.result?.key == .nearby)
        #expect(shooter.result?.foeLosses == FleetLayout.shipCount)
        // Свой аккаунт — баллов нет.
        #expect(shooter.result?.lines.isEmpty == true)
    }

    @Test("Ожидание хода: поле противника не нажимается")
    func waitingSideCannotShoot() {
        let (shooter, target, _) = pair()
        #expect(target.isWaiting)
        target.tap(Coordinate(row: 1, column: 1))
        #expect(target.game.pendingShot == nil)
        #expect(!shooter.isWaiting)
    }

    @Test("Обрыв и возврат связи: партия идёт дальше с того же хода")
    func dropAndRestore() {
        let (shooter, target, wire) = pair()
        wire.cut()
        #expect(shooter.link.isLost && target.link.isLost)
        shooter.tap(Coordinate(row: 1, column: 1))
        #expect(shooter.game.pendingShot == nil, "При обрыве не стреляют")
        wire.restore()
        #expect(shooter.link == .connected && target.link == .connected)
        #expect(shooter.isMyTurn && !target.isMyTurn)
    }

    @Test("Связь не вернулась — партия закрыта без победы")
    func dropWithoutReturn() async {
        let (shooter, target, wire) = pair()
        wire.cut()
        await shooter.waitForReconnect()
        await target.waitForReconnect()
        #expect(shooter.link == .closed)
        #expect(shooter.notice == .connectionClosed)
        #expect(shooter.game.winner == nil && target.game.winner == nil)
        #expect(shooter.result == nil)
    }

    @Test("Сдача: у соперника окно, итог — по кнопке «К результатам»")
    func surrender() {
        let (shooter, target, _) = pair()
        shooter.leave()
        #expect(target.notice == .opponentLeft(won: true))
        #expect(target.result == nil)
        target.showResult()
        #expect(target.result?.didWin == true)
        #expect(target.notice == nil)
    }

    @Test("«Ещё партия» после ухода соперника — окно, а не пустая расстановка")
    func rematchAfterOpponentLeft() {
        let (shooter, target, _) = pair()
        for cell in FleetLayout.canonicalLayout().flatMap(\.cells) { shooter.tap(cell) }
        target.close()
        shooter.playAgain()
        #expect(shooter.notice == .opponentLeft(won: false))
        #expect(shooter.game.round == 0)
    }

    @Test("Подсказки против своего аккаунта нет")
    func noHintAgainstYourself() {
        let (shooter, _, _) = pair(sameAccount: true)
        #expect(!shooter.offersHint)
        #expect(!shooter.canUseHint)
    }
}
