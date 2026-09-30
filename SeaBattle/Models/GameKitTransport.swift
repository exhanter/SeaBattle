//
//  GameKitTransport.swift
//  SeaBattle
//
//  Phase 5 (online): real-time transport over a GKMatch. Drop-in NetworkTransport
//  for the same NetMatch core used by the offline (Multipeer) mode — the
//  authoritative-own-board message flow maps directly onto GKMatch's live
//  send/receive. Delegate callbacks are hopped to the main actor.
//

import Foundation
import GameKit

@MainActor
final class GameKitTransport: NSObject, NetworkTransport {

    var onReceive: ((NetworkMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private let match: GKMatch

    init(match: GKMatch) {
        self.match = match
        super.init()
        match.delegate = self
    }

    func send(_ message: NetworkMessage) {
        guard let data = try? JSONEncoder().encode(message), !match.players.isEmpty else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    /// ПЕРЕХОДНОЕ: переподключение по Game Center — в R3.3b. Пока обрыв
    /// онлайн-партии просто ждёт срок и закрывает её без победы.
    func reconnect() {}

    func disconnect() {
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
}
