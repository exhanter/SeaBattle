//
//  HotSeatGame.swift
//  SeaBattle
//
//  Phase 5a: two humans on one device. Self-contained controller (kept separate
//  from the vs-computer GameLogicViewModel so that mode is untouched). Drives a
//  phase machine: secret ship placement behind a "pass the device" PIN handoff,
//  then alternating fire with a handoff whenever the turn passes (on a miss).
//

import Foundation
import Observation

@MainActor
@Observable
final class HotSeatGame {

    enum Phase: Equatable {
        case setup
        case arrangeHandoff(player: Int)   // pass device to `player` to place ships
        case arrange(player: Int)          // `player` arranges secretly
        case turnHandoff(player: Int)      // pass device to `player` to shoot
        case shooting
        case finished
    }

    private(set) var phase: Phase = .setup
    let boards: [PlayerData] = [PlayerData(name: "Player"), PlayerData(name: "Player")]
    private(set) var names: [String] = ["", ""]
    private(set) var pinHashes: [String?] = [nil, nil]
    private(set) var attacker = 0
    private(set) var winner: Int?

    var soundOn = true

    var defender: Int { 1 - attacker }

    // MARK: - Setup / flow

    func begin(name0: String, pin0: String, name1: String, pin1: String) {
        names = [
            name0.trimmingCharacters(in: .whitespaces),
            name1.trimmingCharacters(in: .whitespaces)
        ]
        pinHashes = [resolvePin(name: name0, pin: pin0), resolvePin(name: name1, pin: pin1)]
        phase = .arrangeHandoff(player: 0)
    }

    /// Resolves and persists a player's PIN: an entered PIN sets/updates it; a
    /// blank field keeps the previously-saved PIN for a returning player. Also
    /// remembers the name (respecting the 10-profile cap).
    private func resolvePin(name: String, pin: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let existing = ProfileStore.shared.profiles.first {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        if pin.isEmpty {
            if existing == nil { ProfileStore.shared.upsert(name: name, pin: "") }
            return existing?.pinHash
        }
        ProfileStore.shared.upsert(name: name, pin: pin)
        return ProfileStore.hash(pin: pin)
    }

    /// Starts a fresh match with the same players.
    func restart() {
        for board in boards { board.clearShips() }
        winner = nil
        attacker = 0
        phase = .arrangeHandoff(player: 0)
    }

    /// Validates a PIN for the given player during a handoff.
    func verify(player: Int, pin: String) -> Bool {
        guard let stored = pinHashes[player] else { return true }
        return stored == ProfileStore.hash(pin: pin)
    }

    /// Called after a successful handoff — advances to the phase the handoff was
    /// gating (arranging or shooting).
    func unlockArrange(player: Int) {
        if boards[player].ships.isEmpty {
            boards[player].shipsRandomArrangement()
        }
        phase = .arrange(player: player)
    }

    func randomize(player: Int) {
        boards[player].shipsRandomArrangement()
    }

    func finishArrangement(player: Int) {
        if player == 0 {
            phase = .arrangeHandoff(player: 1)
        } else {
            attacker = 0
            phase = .turnHandoff(player: 0)
        }
    }

    func startShooting() {
        phase = .shooting
    }

    // MARK: - Firing

    func fire(row: Int, column: Int) {
        guard phase == .shooting, winner == nil else { return }
        let target = boards[defender]
        let r = row - 1, c = column - 1
        guard target.cells[r][c].isAvailable else { return } // already shot or known-empty

        if let shipIndex = target.ships.firstIndex(where: { $0.coordinates.contains(where: { $0 == (row, column) }) }) {
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
                target.defineSafeAreaNearShip(ship: ship) // the no-touch ring is now known-empty
                play("Glass_Break-stephan_schutze-958181291.wav")
            }
            if target.numberShipsDestroyed == 10 {
                winner = attacker
                phase = .finished
                AppState.musicPlayer?.stop()
            }
            // A hit keeps the same attacker firing (no handoff).
        } else {
            target.cells[r][c].cellStatus = .missed
            target.cells[r][c].isAvailable = false
            play("blast_missed.wav")
            attacker = defender
            phase = .turnHandoff(player: attacker)
        }
    }

    private func play(_ sound: String) {
        if soundOn { AppState.playSound(sound: sound) }
    }
}
