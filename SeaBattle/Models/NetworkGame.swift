//
//  NetworkGame.swift
//  SeaBattle
//
//  Phase 5: transport-agnostic networked match. Each device is ONE player and
//  is authoritative over its own board (`own`); `tracking` is what this player
//  knows about the opponent's board from shot results. Turn passes on a miss.
//  Points follow the multiplayer policy: awarded as EXPERT only when the two
//  players are on different accounts (never same-account / hot-seat).
//

import Foundation
import Observation

@MainActor
@Observable
final class NetworkGame {

    enum Phase: Equatable {
        case placing            // choosing my fleet
        case waitingForOpponent // I'm ready, waiting for them
        case myTurn
        case theirTurn
        case finished
    }

    private let transport: NetworkTransport

    // My identity.
    let localName: String
    let localAvatar: String
    private let localAccountID: String
    private let isHost: Bool

    // Opponent identity (filled on handshake).
    private(set) var opponentName = ""
    private(set) var opponentAvatar = HotSeatAvatars.symbols[1]
    private(set) var opponentAccountID: String?

    let own = PlayerData(name: "Player")       // my fleet (authoritative, secret)
    let tracking = PlayerData(name: "Enemy")   // my view of the opponent's board

    private(set) var phase: Phase = .placing
    private(set) var connected = false
    private(set) var iWon: Bool?
    private(set) var busy = false              // awaiting a shot result
    private(set) var opponentShipsSunk = 0     // how many of the opponent's ships I've sunk
    private(set) var revealedHints: [Coordinate] = [] // opponent ship cells revealed to me by hints

    private var iAmReady = false
    private var opponentReady = false

    var soundOn = true

    /// A same-account match (my iPhone + my iPad) earns no points, to stop
    /// farming points against yourself.
    var isSameAccount: Bool { opponentAccountID == localAccountID }

    init(transport: NetworkTransport, name: String, avatar: String, accountID: String, isHost: Bool) {
        self.transport = transport
        self.localName = name
        self.localAvatar = avatar
        self.localAccountID = accountID
        self.isHost = isHost
        own.shipsRandomArrangement()
    }

    // MARK: - Lifecycle

    func start() {
        transport.onReceive = { [weak self] message in self?.handle(message) }
        transport.onConnectionChange = { [weak self] isConnected in
            self?.connected = isConnected
            if isConnected { self?.sendHello() }
        }
        sendHello()
    }

    private func sendHello() {
        transport.send(.hello(HelloPayload(name: localName, avatar: localAvatar,
                                           accountID: localAccountID, isHost: isHost)))
    }

    func randomize() {
        guard phase == .placing else { return }
        own.shipsRandomArrangement()
    }

    /// Confirms my fleet and waits for / begins the match.
    func confirmReady() {
        guard phase == .placing else { return }
        iAmReady = true
        transport.send(.ready)
        phase = .waitingForOpponent
        maybeStart()
    }

    private func maybeStart() {
        guard iAmReady, opponentReady else { return }
        phase = isHost ? .myTurn : .theirTurn
    }

    // MARK: - Firing (I am the shooter)

    func canFire(row: Int, column: Int) -> Bool {
        phase == .myTurn && !busy && tracking.cells[row - 1][column - 1].isAvailable
    }

    func fire(row: Int, column: Int) {
        guard canFire(row: row, column: column) else { return }
        busy = true
        transport.send(.fire(Coordinate(row: row, column: column)))
    }

    // MARK: - Hints (cross-account only)

    var hintCost: Int { AppState.DifficultyLevel.expert.pointsValue }

    /// Hints only make sense against a different account (they cost you points
    /// and pay the opponent). Available on your turn with enough points.
    var canUseHint: Bool {
        phase == .myTurn && !busy && !isSameAccount && ProgressStore.shared.points >= hintCost
    }

    /// Spend points to ask the opponent to reveal one of their ship cells. The
    /// opponent receives compensation points and answers with `.hintReveal`.
    func useHint() {
        guard canUseHint, ProgressStore.shared.spend(hintCost) else { return }
        transport.send(.hintUsed)
    }

    // MARK: - Message handling

    private func handle(_ message: NetworkMessage) {
        switch message {
        case .hello(let payload):
            opponentName = payload.name
            opponentAvatar = payload.avatar
            opponentAccountID = payload.accountID

        case .ready:
            opponentReady = true
            maybeStart()

        case .fire(let coordinate):
            resolveIncomingShot(coordinate)

        case .result(let payload):
            applyResult(payload)

        case .hintUsed:
            // Opponent used a hint against me → I receive compensation points and
            // reveal one of my still-unhit ship cells to them.
            if !isSameAccount { ProgressStore.shared.addPoints(AppState.DifficultyLevel.expert.pointsValue) }
            let candidates = own.ships
                .filter { !$0.isDestroyed }
                .flatMap { $0.coordinates }
                .filter { own.cells[$0.0 - 1][$0.1 - 1].isAvailable }
            if let pick = candidates.randomElement() {
                transport.send(.hintReveal(Coordinate(pick)))
            }

        case .hintReveal(let coordinate):
            if !revealedHints.contains(coordinate) { revealedHints.append(coordinate) }

        case .rematch:
            resetForRematch()

        case .quit:
            phase = .finished
        }
    }

    // MARK: - Defender side

    private func resolveIncomingShot(_ coordinate: Coordinate) {
        let r = coordinate.row - 1, c = coordinate.column - 1
        guard own.cells[r][c].isAvailable else { return }

        guard let shipIndex = own.ships.firstIndex(where: { $0.coordinates.contains(where: { $0 == (coordinate.row, coordinate.column) }) }) else {
            own.cells[r][c].cellStatus = .missed
            own.cells[r][c].isAvailable = false
            play("blast_missed.wav")
            transport.send(.result(ResultPayload(at: coordinate, outcome: .missed, sunkShip: nil, defenderLost: false)))
            phase = .myTurn // opponent missed — my turn to shoot
            return
        }

        own.cells[r][c].cellStatus = .showShipOnFire
        own.cells[r][c].isAvailable = false
        play("blast_onfire2.wav")

        let ship = own.ships[shipIndex]
        let sunk = ship.coordinates.allSatisfy { coord in
            let status = own.cells[coord.0 - 1][coord.1 - 1].cellStatus
            return status == .showShipOnFire || status == .destroyed
        }
        var sunkCells: [Coordinate]?
        if sunk {
            for coord in ship.coordinates { own.cells[coord.0 - 1][coord.1 - 1].cellStatus = .destroyed }
            own.ships[shipIndex].isDestroyed = true
            sunkCells = ship.coordinates.map(Coordinate.init)
            play("Glass_Break-stephan_schutze-958181291.wav")
        }
        let lost = own.numberShipsDestroyed == 10
        transport.send(.result(ResultPayload(at: coordinate,
                                             outcome: sunk ? .sunk : .hit,
                                             sunkShip: sunkCells,
                                             defenderLost: lost)))
        if lost {
            finish(iWon: false)
        } // else opponent hit — stays their turn
    }

    // MARK: - Shooter side

    private func applyResult(_ payload: ResultPayload) {
        let r = payload.at.row - 1, c = payload.at.column - 1
        tracking.cells[r][c].cellStatus = (payload.outcome == .missed) ? .missed : .onFire
        tracking.cells[r][c].isAvailable = false
        if let sunkShip = payload.sunkShip {
            opponentShipsSunk += 1
            for coord in sunkShip {
                tracking.cells[coord.row - 1][coord.column - 1].cellStatus = .destroyed
                tracking.cells[coord.row - 1][coord.column - 1].isAvailable = false
            }
        }
        busy = false

        if payload.defenderLost {
            finish(iWon: true)
        } else if payload.outcome == .missed {
            phase = .theirTurn
        } else {
            phase = .myTurn // a hit — I fire again
        }
    }

    // MARK: - End / rematch

    private func finish(iWon won: Bool) {
        iWon = won
        phase = .finished
        AppState.stopMusic()
        // Points only for cross-account matches (expert values).
        guard !isSameAccount else { return }
        if won {
            ProgressStore.shared.recordWin(at: .expert)
        } else {
            ProgressStore.shared.recordLoss()
        }
    }

    func requestRematch() {
        transport.send(.rematch)
        resetForRematch()
    }

    private func resetForRematch() {
        own.clearShips()
        own.shipsRandomArrangement()
        tracking.clearShips()
        iWon = nil
        iAmReady = false
        opponentReady = false
        busy = false
        opponentShipsSunk = 0
        revealedHints = []
        phase = .placing
    }

    private func play(_ sound: String) {
        if soundOn { AppState.playSound(sound: sound) }
    }
}
