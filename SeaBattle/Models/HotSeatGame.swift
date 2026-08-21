//
//  HotSeatGame.swift
//  SeaBattle
//
//  Phase 5a: two humans on one device. Self-contained controller (kept separate
//  from the vs-computer GameLogicViewModel). A "session" is the run of games two
//  players play via "Play again": names, avatars, PINs and the win tally all
//  live in memory for the session and vanish when the player leaves to the menu.
//  No global points/stats are awarded (multiplayer is anti-cheat exempt).
//

import Foundation
import Observation

@MainActor
@Observable
final class HotSeatGame {

    struct Player: Codable {
        var name: String
        var avatar: String
        var pinHash: String?   // session-only
        var sessionWins: Int = 0
    }

    enum Phase: Equatable, Codable {
        case setup
        case arrangeHandoff(player: Int)
        case arrange(player: Int)
        case turnHandoff(player: Int)
        case shooting
        case finished
    }

    private(set) var phase: Phase = .setup
    let boards: [PlayerData] = [PlayerData(name: "Player"), PlayerData(name: "Player")]
    private(set) var players: [Player] = [
        Player(name: "", avatar: HotSeatAvatars.symbols[0]),
        Player(name: "", avatar: HotSeatAvatars.symbols[1])
    ]
    private(set) var attacker = 0
    private(set) var winner: Int?

    var soundOn = true
    /// When true, the ring around a sunk ship is auto-revealed as empty
    /// (optional beginner protection). Default off = you may fire there.
    var revealAroundSunk = false

    var defender: Int { 1 - attacker }

    // MARK: - Setup / flow

    func begin(name0: String, avatar0: String, pin0: String,
               name1: String, avatar1: String, pin1: String) {
        players = [
            Player(name: name0.trimmingCharacters(in: .whitespaces), avatar: avatar0,
                   pinHash: pin0.isEmpty ? nil : ProfileStore.hash(pin: pin0)),
            Player(name: name1.trimmingCharacters(in: .whitespaces), avatar: avatar1,
                   pinHash: pin1.isEmpty ? nil : ProfileStore.hash(pin: pin1))
        ]
        // Remember the players (name + avatar only) for next time.
        ProfileStore.shared.upsert(name: name0, avatar: avatar0)
        ProfileStore.shared.upsert(name: name1, avatar: avatar1)
        // First player already holds the device — skip the pass-the-device screen
        // and go straight to placement with an auto-arranged fleet. The handoff is
        // still shown before player 2 places (and before each turn).
        unlockArrange(player: 0)
    }

    func verify(player: Int, pin: String) -> Bool {
        guard let stored = players[player].pinHash else { return true }
        return stored == ProfileStore.hash(pin: pin)
    }

    func unlockArrange(player: Int) {
        if boards[player].ships.isEmpty {
            boards[player].shipsRandomArrangement()
        }
        phase = .arrange(player: player)
        persist()
    }

    func randomize(player: Int) {
        boards[player].shipsRandomArrangement()
        persist()
    }

    func finishArrangement(player: Int) {
        if player == 0 {
            phase = .arrangeHandoff(player: 1)
        } else {
            attacker = 0
            phase = .turnHandoff(player: 0)
        }
        persist()
    }

    func startShooting() {
        phase = .shooting
        persist()
    }

    /// New game with the same players — keeps names, avatars, PINs and the
    /// session win tally.
    func restart() {
        for board in boards { board.clearShips() }
        winner = nil
        attacker = 0
        phase = .arrangeHandoff(player: 0)
        persist()
    }

    // MARK: - Firing

    enum ShotResult { case hit, sunk, missed, win }

    /// Whether a shot at this cell is currently legal.
    func canFire(row: Int, column: Int) -> Bool {
        phase == .shooting && winner == nil && boards[defender].cells[row - 1][column - 1].isAvailable
    }

    /// Resolves a shot but does NOT change the turn/phase — the view drives the
    /// transitions after playing the shot animation (so the result is visible
    /// before the device is passed). RETURNS the outcome.
    @discardableResult
    func fire(row: Int, column: Int) -> ShotResult? {
        guard canFire(row: row, column: column) else { return nil }
        let target = boards[defender]
        let r = row - 1, c = column - 1

        guard let shipIndex = target.ships.firstIndex(where: { $0.coordinates.contains(where: { $0 == (row, column) }) }) else {
            target.cells[r][c].cellStatus = .missed
            target.cells[r][c].isAvailable = false
            play("blast_missed.wav")
            persist()
            return .missed
        }

        target.cells[r][c].cellStatus = .onFire
        target.cells[r][c].isAvailable = false
        play("blast_onfire2.wav")

        let ship = target.ships[shipIndex]
        let sunk = ship.coordinates.allSatisfy { coord in
            let status = target.cells[coord.0 - 1][coord.1 - 1].cellStatus
            return status == .onFire || status == .destroyed
        }
        if sunk {
            for coord in ship.coordinates {
                target.cells[coord.0 - 1][coord.1 - 1].cellStatus = .destroyed
            }
            target.ships[shipIndex].isDestroyed = true
            // Firing around a sunk ship stays allowed unless the player opted in.
            if revealAroundSunk { target.markSafeAreaAsMissed(ship: ship) }
            play("Glass_Break-stephan_schutze-958181291.wav")
        }
        if target.numberShipsDestroyed == 10 {
            winner = attacker
            players[attacker].sessionWins += 1
            AppState.musicPlayer?.stop()
            persist()
            return .win
        }
        persist()
        return sunk ? .sunk : .hit
    }

    /// Passes the turn to the other player (after a miss). View calls this once
    /// the miss animation has played.
    func passTurn() {
        guard winner == nil, phase == .shooting else { return }
        attacker = defender
        phase = .turnHandoff(player: attacker)
        persist()
    }

    /// Ends the match (after the winning-shot animation).
    func finishMatch() {
        phase = .finished
        persist()
    }

    private func play(_ sound: String) {
        if soundOn { AppState.playSound(sound: sound) }
    }

    // MARK: - Session persistence

    func snapshot() -> HotSeatSnapshot {
        HotSeatSnapshot(players: players,
                        boardA: PlayerSnapshot(boards[0]),
                        boardB: PlayerSnapshot(boards[1]),
                        phase: phase,
                        attacker: attacker,
                        winner: winner)
    }

    /// Restores a saved session into this game.
    func restore(from snapshot: HotSeatSnapshot) {
        players = snapshot.players
        snapshot.boardA.restore(into: boards[0])
        snapshot.boardB.restore(into: boards[1])
        attacker = snapshot.attacker
        winner = snapshot.winner
        phase = snapshot.phase
    }

    private func persist() {
        HotSeatStore.save(snapshot())
    }
}

/// A serializable snapshot of a whole hot-seat session (players + both boards +
/// where the session is), so it survives app relaunch.
struct HotSeatSnapshot: Codable {
    var players: [HotSeatGame.Player]
    var boardA: PlayerSnapshot
    var boardB: PlayerSnapshot
    var phase: HotSeatGame.Phase
    var attacker: Int
    var winner: Int?
}
