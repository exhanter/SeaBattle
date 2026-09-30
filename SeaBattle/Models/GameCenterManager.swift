//
//  GameCenterManager.swift
//  SeaBattle
//
//  Phase 5 (online): Game Center authentication. No backend — Apple provides
//  identity (gamePlayerID) and real-time matchmaking. Requires the Game Center
//  capability on the app target.
//
//  R3.3b: `signIn()` answers once — signed in or not. Game Center calls the
//  handler again whenever the state changes, and after the player has once
//  dismissed the sign-in sheet it stops asking until the next launch; a
//  second `signIn()` then answers from the current state instead of waiting
//  for a call that never comes.
//

import Foundation
import Observation
import GameKit

@MainActor
@Observable
final class GameCenterManager {

    static let shared = GameCenterManager()

    private(set) var isAuthenticated = false
    /// Set when Game Center wants us to present a sign-in screen.
    var authViewController: UIViewController?

    @ObservationIgnored private var handlerInstalled = false
    /// The handler is installed but has not answered yet.
    @ObservationIgnored private var awaitingHandler = false
    @ObservationIgnored private var waiters: [CheckedContinuation<Bool, Never>] = []

    var localPlayerID: String { GKLocalPlayer.local.gamePlayerID }
    var localDisplayName: String { GKLocalPlayer.local.displayName }

    /// Installs the authentication handler once. Game Center calls it now and
    /// whenever the auth state changes.
    func authenticate() {
        guard !handlerInstalled else {
            isAuthenticated = GKLocalPlayer.local.isAuthenticated
            return
        }
        handlerInstalled = true
        awaitingHandler = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    // The sheet is on screen — the answer comes with the next call.
                    self.authViewController = viewController
                } else {
                    self.authViewController = nil
                    self.awaitingHandler = false
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    self.resume(self.isAuthenticated)
                }
            }
        }
    }

    /// Signed in — or not: declined, Game Center turned off, no account.
    func signIn() async -> Bool {
        if GKLocalPlayer.local.isAuthenticated {
            isAuthenticated = true
            return true
        }
        // Nobody is going to call the handler again: answer now.
        if handlerInstalled && !awaitingHandler && authViewController == nil {
            return false
        }
        // Game Center may never answer: on the simulator (01.10) its sign-in
        // overlay (GameOverlayUI) failed to start, the handler was never
        // called and the screen hung on "checking". No answer in time — not
        // signed in.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.signInTimeout)
            guard let self, !self.waiters.isEmpty, self.authViewController == nil else { return }
            self.awaitingHandler = false
            self.resume(GKLocalPlayer.local.isAuthenticated)
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            authenticate()
        }
    }

    /// How long to wait for Game Center while its sign-in sheet is not up.
    static let signInTimeout: Duration = .seconds(15)

    /// The sign-in sheet was swiped away without an answer from Game Center.
    func sheetDismissed() {
        guard authViewController != nil else { return }
        authViewController = nil
        awaitingHandler = false
        resume(GKLocalPlayer.local.isAuthenticated)
    }

    private func resume(_ value: Bool) {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume(returning: value) }
    }
}
