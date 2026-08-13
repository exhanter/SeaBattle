//
//  NetworkMessage.swift
//  SeaBattle
//
//  Phase 5: the transport-agnostic wire protocol for networked play. Each peer
//  is AUTHORITATIVE over its OWN board: you never send your ship positions —
//  you only answer incoming shots with a result. This makes ship positions
//  un-snoopable and needs no server. The same messages travel over any
//  transport (MultipeerConnectivity for offline/nearby, GameKit for online).
//

import Foundation

/// Handshake info exchanged once when a match connects.
struct HelloPayload: Codable, Sendable {
    var name: String
    var avatar: String
    /// Stable per-account id (e.g. CloudKit user record id / Game Center
    /// gamePlayerID). Used to detect a same-account match (no points then).
    var accountID: String
    var isHost: Bool
}

/// The defender's answer to an incoming shot.
struct ResultPayload: Codable, Sendable {
    var at: Coordinate
    var outcome: ShotOutcome        // missed / hit / sunk
    var sunkShip: [Coordinate]?     // the whole ship's cells, revealed on a sink
    var defenderLost: Bool          // the defender's last ship just went down
}

enum NetworkMessage: Codable, Sendable {
    case hello(HelloPayload)
    case ready                       // my fleet is placed
    case fire(Coordinate)            // I shoot this cell of your board
    case result(ResultPayload)       // your answer to my shot
    case hintUsed                    // I spent a hint → you get compensation points
    case rematch
    case quit
}

/// Abstracts the underlying networking. Implementations must invoke the
/// callbacks on the main actor (the game state is main-actor isolated).
@MainActor
protocol NetworkTransport: AnyObject {
    var onReceive: ((NetworkMessage) -> Void)? { get set }
    var onConnectionChange: ((Bool) -> Void)? { get set }
    func send(_ message: NetworkMessage)
}

/// In-process transport that wires two `NetworkGame`s directly together, for
/// tests and previews (no radios involved).
@MainActor
final class LoopbackTransport: NetworkTransport {
    var onReceive: ((NetworkMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    weak var peer: LoopbackTransport?

    func send(_ message: NetworkMessage) {
        peer?.onReceive?(message)
    }

    /// Connects two loopback transports back-to-back.
    static func pair() -> (LoopbackTransport, LoopbackTransport) {
        let a = LoopbackTransport()
        let b = LoopbackTransport()
        a.peer = b
        b.peer = a
        return (a, b)
    }
}
