//
//  GameCenterManager.swift
//  SeaBattle
//
//  Phase 5 (online): Game Center authentication. No backend — Apple provides
//  identity (gamePlayerID) and real-time matchmaking. Requires the Game Center
//  capability on the app target.
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

    private var handlerInstalled = false

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
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    self.authViewController = viewController
                } else {
                    self.authViewController = nil
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                }
            }
        }
    }
}
