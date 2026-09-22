//
//  NetworkGame.swift
//  SeaBattle
//
//  Phase 5: transport-agnostic networked match. Each device is ONE player and
//  is authoritative over its own board (`own`); `tracking` is what this player
//  knows about the opponent's board from shot results. Turn passes on a miss.
//  Points follow the multiplayer policy: paid at the expert rate, and only when
//  the two players are on different accounts (never same-account / hot-seat).
//  The result is filed under the mode's own statistics row since R0.7 — it used
//  to be counted as a win over the computer's expert level (audit finding A7).
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

    private let transport: any NetworkTransport

    /// The statistics row this match is filed under — `.nearby` over Multipeer,
    /// `.online` over Game Center. The rules are identical; the row is the only
    /// difference between the two transports (R0.7).
    let statKey: StatKey

    var mode: GameMode { statKey.mode }

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

    init(transport: any NetworkTransport, statKey: StatKey, name: String, avatar: String,
         accountID: String, isHost: Bool) {
        self.transport = transport
        self.statKey = statKey
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
            if !isSameAccount { ProgressStore.shared.addPoints(hintCost) }
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

    /// Resolves the opponent's shot at my fleet and reports the outcome back.
    ///
    /// This device is the only authority on its own board, so this is where the
    /// rules run — since R0.4 on `Board`, not on a third hand-written copy of
    /// hit / sunk / lost (audit finding A1).
    private func resolveIncomingShot(_ coordinate: Coordinate) {
        var board = own.coreBoard
        let result = board.apply(shotAt: coordinate)
        own.apply(board)

        let outcome: ShotOutcome
        var sunkCells: [Coordinate]?
        switch result {
        case .miss:
            play("blast_missed.wav")
            outcome = .missed
        case .hit:
            play("blast_onfire2.wav")
            outcome = .hit
        case .sunk(let ship):
            play("blast_onfire2.wav")
            play("Glass_Break-stephan_schutze-958181291.wav")
            outcome = .sunk
            sunkCells = ship.cells
        case .repeated, .offBoard:
            // A cell they have already fired at, or one off the board. Nothing
            // changed, so answering would desynchronise their turn — a sound
            // peer never sends this.
            return
        }

        let lost = board.isFleetDestroyed
        transport.send(.result(ResultPayload(at: coordinate,
                                             outcome: outcome,
                                             sunkShip: sunkCells,
                                             defenderLost: lost)))
        if lost {
            finish(iWon: false)
        } else if outcome == .missed {
            phase = .myTurn // opponent missed — my turn to shoot
        } // else opponent hit — stays their turn
    }

    // MARK: - Shooter side

    /// Records what the opponent said about my shot onto my tracking board.
    ///
    /// `tracking` holds no fleet — the opponent's layout lives on their device —
    /// so this uses the core's manual marking, the same path the paper game
    /// takes. The sunk tally is then read off the board as connected runs of
    /// sunk cells rather than counted by hand, so it cannot drift from what is
    /// drawn.
    private func applyResult(_ payload: ResultPayload) {
        var board = tracking.coreBoard
        board.mark(payload.outcome == .missed ? .miss : .hit, at: payload.at)
        for coordinate in payload.sunkShip ?? [] {
            board.mark(.sunk, at: coordinate)
        }
        tracking.apply(board)
        opponentShipsSunk = board.sunkShipCount
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
        // Nothing is recorded for a same-account match (my iPhone against my
        // iPad): the points would be farmed off myself, and the win would be a
        // win over myself.
        guard !isSameAccount else { return }
        if won {
            ProgressStore.shared.recordWin(statKey)
        } else {
            ProgressStore.shared.recordLoss(statKey)
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
