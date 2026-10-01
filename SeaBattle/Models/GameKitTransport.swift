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
///
/// R3.3c: iOS 26+ only (the customer's decision, 01.10 — online play and Pro
/// are not offered on iOS 18). Invite codes are Game Center party codes on a
/// game activity: the activity must be described in the GameKit bundle / App
/// Store Connect under `activityID`, with party codes on and exactly two
/// players. Without it `openParty` throws and the lobby says invites are
/// unavailable; the random opponent still works.
@available(iOS 26.0, *)
@MainActor
final class GameCenterService: OnlineService {

    /// The activity identifier in the GameKit bundle / App Store Connect.
    static let activityID = "nl.brapps.SeaBattle.versus"

    var playerID: String { GameCenterManager.shared.localPlayerID }
    var playerName: String { GameCenterManager.shared.localDisplayName }

    private var definition: GKGameActivityDefinition?
    private var party: GKGameActivity?

    enum PartyError: Error {
        /// The activity is not configured (or not loaded yet).
        case notConfigured
    }

    func isOnline() async -> Bool {
        // The first path is the current one; one answer is enough.
        for await path in NWPathMonitor() {
            return path.status == .satisfied
        }
        return false
    }

    /// Signs in and loads the activity definition: opening a party is then
    /// synchronous, the lobby does not wait on the button.
    func signIn() async -> Bool {
        guard await GameCenterManager.shared.signIn() else { return false }
        if definition == nil {
            definition = try? await GKGameActivityDefinition.all.first { $0.identifier == Self.activityID }
        }
        return true
    }

    func openParty(_ code: InviteCode) throws -> URL? {
        closeParty()
        guard let definition, definition.supportsPartyCode else { throw PartyError.notConfigured }
        let activity = try GKGameActivity.start(definition: definition, partyCode: code.text)
        party = activity
        return activity.partyURL
    }

    func closeParty() {
        party?.end()
        party = nil
    }

    func findMatch(_ kind: MatchKind) async throws -> FoundMatch {
        let match: GKMatch
        switch kind {
        case .random:
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            match = try await GKMatchmaker.shared().findMatch(for: request)
        case .party:
            guard let party else { throw PartyError.notConfigured }
            // Matches only players in the same party (the same code).
            match = try await party.findMatch()
        }
        GKMatchmaker.shared().finishMatchmaking(for: match)
        let transport = GameKitTransport(match: match)
        return FoundMatch(transport: transport, connected: transport.isConnected)
    }

    /// The party search is a classic matchmaking request under the hood, so
    /// the shared matchmaker cancels it too (not verified on devices yet).
    func cancelSearch() {
        GKMatchmaker.shared().cancel()
    }
}

// MARK: - Links and the Games app

/// Delivers party codes from outside the app: a shared `partyURL` tapped in
/// Messages, or «Play» in the Games app. The shell watches `pendingCode` and
/// opens «Online» straight into joining.
///
/// GameKit hands the activity over only after sign-in, and signing in at
/// every launch would show the Game Center banner to everyone. So on
/// launch and on every return to the foreground the router first asks
/// whether an activity is waiting (`hasPendingGameActivities`, allowed before
/// sign-in) and signs in only then.
@available(iOS 26.0, *)
@MainActor
@Observable
final class GameActivityRouter: NSObject, GKLocalPlayerListener {

    static let shared = GameActivityRouter()

    /// A code to join, not yet taken by the shell.
    var pendingCode: InviteCode?

    @ObservationIgnored private var registered = false

    /// On launch and on every activation.
    func checkPending() async {
        if !registered {
            registered = true
            GKLocalPlayer.local.register(self)
        }
        guard await GKGameActivity.hasPendingGameActivities else { return }
        GameCenterManager.shared.authenticate()
    }

    nonisolated func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity) async -> Bool {
        let partyCode = activity.partyCode
        let identifier = activity.activityDefinition.identifier
        return await MainActor.run {
            guard identifier == GameCenterService.activityID,
                  let partyCode, let code = InviteCode(partyCode: partyCode) else { return false }
            pendingCode = code
            return true
        }
    }
}
