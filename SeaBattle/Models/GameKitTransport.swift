//
//  GameKitTransport.swift
//  SeaBattle
//
//  Phase 5 (online): real-time transport over a GKMatch. Drop-in NetworkTransport
//  for the same NetMatch core used by the offline (Multipeer) mode — the
//  authoritative-own-board message flow maps directly onto GKMatch's live
//  send/receive. Delegate callbacks are hopped to the main actor.
//
//  R3.3b: reconnection and programmatic matchmaking. In a two-player match
//  GameKit reinvites a disconnected player itself when the delegate asks it
//  to (`shouldReinviteDisconnectedPlayer`); the player's return arrives as
//  an ordinary `.connected`, so `reconnect()` has nothing to do. The match
//  still closes after its grace period if the player never comes back.
//

import Foundation
import GameKit
import Network

@MainActor
final class GameKitTransport: NSObject, NetworkTransport {

    var onReceive: ((NetworkMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private let match: GKMatch
    /// Our own `disconnect()` — no reinviting after it.
    private var isClosed = false

    init(match: GKMatch) {
        self.match = match
        super.init()
        match.delegate = self
    }

    /// Everybody expected is already in: no `.connected` callback is coming.
    var isConnected: Bool { match.expectedPlayerCount == 0 && !match.players.isEmpty }

    func send(_ message: NetworkMessage) {
        guard let data = try? JSONEncoder().encode(message), !match.players.isEmpty else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    /// GameKit reinvites on its own (see the header).
    func reconnect() {}

    func disconnect() {
        isClosed = true
        match.delegate = nil
        match.disconnect()
    }
}

extension GameKitTransport: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = try? JSONDecoder().decode(NetworkMessage.self, from: data) else { return }
        Task { @MainActor in self.onReceive?(message) }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.onConnectionChange?(true)
            case .disconnected: self.onConnectionChange?(false)
            default: break
            }
        }
    }

    /// Two players only, so GameKit offers to bring the other one back.
    nonisolated func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
        MainActor.assumeIsolated { !isClosed }
    }
}

// MARK: - Online service

/// Game Center and the network path behind the online lobby (`OnlineLobby`).
@MainActor
final class GameCenterService: OnlineService {

    var playerID: String { GameCenterManager.shared.localPlayerID }
    var playerName: String { GameCenterManager.shared.localDisplayName }

    func isOnline() async -> Bool {
        // The first path is the current one; one answer is enough.
        for await path in NWPathMonitor() {
            return path.status == .satisfied
        }
        return false
    }

    func signIn() async -> Bool {
        await GameCenterManager.shared.signIn()
    }

    func findMatch(playerGroup: Int) async throws -> FoundMatch {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        // Players are only matched within one group: 0 is the random
        // opponent, an invite code is a group of its own (decision R3.3).
        request.playerGroup = playerGroup
        let match = try await GKMatchmaker.shared().findMatch(for: request)
        GKMatchmaker.shared().finishMatchmaking(for: match)
        let transport = GameKitTransport(match: match)
        return FoundMatch(transport: transport, connected: transport.isConnected)
    }

    func cancelSearch() {
        GKMatchmaker.shared().cancel()
    }
}
