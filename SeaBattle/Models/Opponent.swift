//
//  Opponent.swift
//  SeaBattle
//
//  Phase 0 scaffolding: a transport-agnostic opponent abstraction. Only
//  `ComputerOpponent` conforms, driven by `BattleController` + `GameEngine`:
//  two players on one device (`DuelGame`) and the network game (`NetGame`)
//  ended up with rule types of their own instead.
//

import Foundation

/// The outcome of a single shot, independent of any UI/cell representation.
enum ShotOutcome: String, Codable, Sendable {
    case missed
    case hit
    case sunk
}

/// A source of ship placement and shots. Implementations may be local (AI or a
/// second human) or remote (network). Main-actor isolated because all current
/// implementations mutate observable game/UI state.
@MainActor
protocol Opponent: AnyObject {
    /// Human-readable name shown in the UI (player name, "Computer", etc.).
    var displayName: String { get }

    /// Provides this opponent's fleet at the start of a match.
    func provideFleet() async -> [Ship]

    /// Returns the next cell this opponent fires at.
    func nextShot() async -> Coordinate

    /// Informs the opponent of the outcome of its most recent shot so it can
    /// update its own targeting state.
    func reportOutcome(_ outcome: ShotOutcome, at coordinate: Coordinate) async
}
