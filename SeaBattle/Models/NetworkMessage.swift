//
//  NetworkMessage.swift
//  SeaBattle
//
//  The transport-agnostic wire protocol for networked play. Each peer is
//  AUTHORITATIVE over its OWN board: you never send your ship positions — you
//  only answer incoming shots with a result. This makes ship positions
//  un-snoopable and needs no server. The same messages travel over any
//  transport (MultipeerConnectivity for nearby play, GameKit for online).
//
//  Version 2 (R3.3) makes every message safe to send twice. A connection can
//  drop between a shot and its answer, and after reconnecting both sides
//  resend what is still pending (`NetGame.resync()`): a shot carries its
//  number, and the defender answers a shot it has already resolved with the
//  same answer instead of firing again. A repeated shot is legal in the rules
//  (spec 4.5), so without the number a resent shot would be a second shot.
//

import Foundation

/// Handshake, sent by both sides on every (re)connection.
struct NetHello: Codable, Equatable, Sendable {
    var name: String
    var glyph: String
    var colorIndex: Int
    /// Stable per-account id (CloudKit user record / Game Center player id).
    /// Used to detect a same-account match (no points, no statistics then).
    var accountID: String
    /// Random per match. Decides roles and the first shooter without a
    /// separate message: both sides compute the same thing from two nonces.
    var nonce: UInt64
    var version: Int
}

/// A shot at the opponent's board. `seq` counts the shooter's shots in the
/// round from zero.
struct NetShot: Codable, Equatable, Sendable {
    var round: Int
    var seq: Int
    var at: Coordinate
}

/// The defender's answer to a shot.
struct NetAnswer: Codable, Equatable, Sendable {
    var round: Int
    var seq: Int
    var at: Coordinate
    var outcome: FeedOutcome
    /// The whole ship's cells, revealed on a sink.
    var sunkShip: [Coordinate]?
    /// The defender's last ship just went down.
    var defenderLost: Bool
}

enum NetworkMessage: Codable, Equatable, Sendable {
    case hello(NetHello)
    /// The answer to `hello`. Without it the first hello can be lost: it is
    /// sent the moment the link comes up, possibly before the other side has
    /// started listening. Not answered itself, so the two never loop.
    case welcome(NetHello)
    /// My fleet is placed for this round.
    case ready(round: Int)
    case shot(NetShot)
    case answer(NetAnswer)
    /// I spent points on a hint: reveal one of your ship cells, and receive
    /// the points as compensation.
    case hintRequest(round: Int, id: Int)
    /// `nil` — nothing left to reveal.
    case hintReveal(round: Int, id: Int, at: Coordinate?)
    /// I want another match; `round` is the round I have moved on to.
    case rematch(round: Int)
    /// I left on purpose. During the battle that is a surrender (spec 4.8).
    case quit
}

/// Abstracts the underlying networking. Implementations must invoke the
/// callbacks on the main actor (the game state is main-actor isolated).
@MainActor
protocol NetworkTransport: AnyObject {
    var onReceive: ((NetworkMessage) -> Void)? { get set }
    var onConnectionChange: ((Bool) -> Void)? { get set }
    func send(_ message: NetworkMessage)
    /// One reconnection attempt after the link dropped. Transports that
    /// cannot reconnect do nothing — the match then closes after its grace
    /// period (spec 4.8).
    func reconnect()
    func disconnect()
}

/// A transport that exists before the opponent does (spec 4.4): the match is
/// created while the invite code is still being searched for, so the fleet
/// can be placed in advance. Until `attach(_:connected:)` everything sent is
/// dropped — nobody is listening yet, and the handshake is repeated on the
/// connection anyway (`hello` makes the other side resend `ready`).
@MainActor
final class DeferredTransport: NetworkTransport {
    var onReceive: ((NetworkMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    /// The match closed the transport before or after the opponent came — the
    /// search behind it has to stop too.
    var onDisconnect: (() -> Void)?
    private(set) var inner: (any NetworkTransport)?
    private(set) var isClosed = false

    var isAttached: Bool { inner != nil }

    /// The opponent is found. `connected` — the link is already up, so no
    /// separate "connected" callback is coming from the real transport.
    func attach(_ transport: any NetworkTransport, connected: Bool) {
        guard inner == nil, !isClosed else {
            transport.disconnect()
            return
        }
        inner = transport
        // Through `self`, not captured closures: the match may set its
        // callbacks after the attach.
        transport.onReceive = { [weak self] message in self?.onReceive?(message) }
        transport.onConnectionChange = { [weak self] up in self?.onConnectionChange?(up) }
        if connected { onConnectionChange?(true) }
    }

    func send(_ message: NetworkMessage) {
        inner?.send(message)
    }

    func reconnect() {
        inner?.reconnect()
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        inner?.disconnect()
        onDisconnect?()
    }
}

/// In-process transport that wires two matches directly together, for tests
/// and previews (no radios involved). The link can be cut and restored, and
/// messages sent while it is down are lost — exactly what a dropped
/// connection does.
@MainActor
final class LoopbackTransport: NetworkTransport {
    var onReceive: ((NetworkMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    weak var peer: LoopbackTransport?
    private(set) var isLinked = true
    /// Everything this side sent, delivered or not — for tests.
    private(set) var sent: [NetworkMessage] = []

    func send(_ message: NetworkMessage) {
        sent.append(message)
        guard isLinked, peer?.isLinked == true else { return }
        peer?.onReceive?(message)
    }

    func reconnect() {}

    func disconnect() {
        cut()
    }

    /// Drops the link on both sides.
    func cut() {
        guard isLinked else { return }
        isLinked = false
        peer?.isLinked = false
        onConnectionChange?(false)
        peer?.onConnectionChange?(false)
    }

    /// Restores the link on both sides.
    func restore() {
        guard !isLinked else { return }
        isLinked = true
        peer?.isLinked = true
        onConnectionChange?(true)
        peer?.onConnectionChange?(true)
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
