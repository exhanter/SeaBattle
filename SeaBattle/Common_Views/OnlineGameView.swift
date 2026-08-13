//
//  OnlineGameView.swift
//  SeaBattle
//
//  Phase 5 (online): authenticate with Game Center, present the real-time
//  matchmaker, then run the match through the shared NetworkGame + NetworkBattleView.
//

import SwiftUI
import GameKit

private let onlineAccent = Color(red: 248/255, green: 255/255, blue: 0/255)

struct OnlineGameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var gc = GameCenterManager.shared
    @State private var showMatchmaker = false
    @State private var transport: GameKitTransport?
    @State private var game: NetworkGame?

    var body: some View {
        Group {
            if let game {
                NetworkBattleView(game: game, onExit: leave)
            } else {
                HotSeatChrome(title: "Play online", onClose: leave) { _ in
                    VStack(spacing: 16) {
                        ProgressView().tint(.white)
                        Text(gc.isAuthenticated ? "Finding an opponent…" : "Signing in to Game Center…")
                            .foregroundColor(.white.opacity(0.85))
                    }
                } bottomBar: { size in
                    Button { leave() } label: {
                        Text("Cancel")
                            .font(.custom("Dorsa", size: size.width * 0.095))
                            .foregroundColor(onlineAccent)
                            .shadow(color: .white, radius: 1)
                    }
                }
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear { gc.authenticate() }
        .onChange(of: gc.isAuthenticated) { _, ok in
            if ok && game == nil { showMatchmaker = true }
        }
        .sheet(isPresented: authBinding) {
            if let vc = gc.authViewController { GameCenterVCPresenter(viewController: vc) }
        }
        .fullScreenCover(isPresented: $showMatchmaker) {
            MatchmakerView(onMatch: startMatch, onDismiss: {
                showMatchmaker = false
                if game == nil { leave() }
            })
        }
        .onDisappear { appState.manualShipArrangement = false }
    }

    private var authBinding: Binding<Bool> {
        Binding(get: { gc.authViewController != nil },
                set: { if !$0 { gc.authViewController = nil } })
    }

    private func startMatch(_ match: GKMatch) {
        showMatchmaker = false
        let t = GameKitTransport(match: match)
        transport = t
        let localID = gc.localPlayerID
        let remoteID = match.players.first?.gamePlayerID ?? ""
        let isHost = localID < remoteID // deterministic first mover, same on both sides
        let avatar = ProfileStore.shared.profiles.first?.avatar ?? HotSeatAvatars.symbols[0]
        let g = NetworkGame(transport: t, name: gc.localDisplayName, avatar: avatar,
                            accountID: localID, isHost: isHost)
        g.soundOn = appState.soundOn
        g.start()
        game = g
    }

    private func leave() {
        transport?.disconnect()
        appState.manualShipArrangement = false
        dismiss()
    }
}

// MARK: - UIKit bridges

/// Presents a GameKit-provided view controller (the sign-in screen).
private struct GameCenterVCPresenter: UIViewControllerRepresentable {
    let viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// The real-time matchmaker (2 players).
private struct MatchmakerView: UIViewControllerRepresentable {
    var onMatch: (GKMatch) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> GKMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        let controller = GKMatchmakerViewController(matchRequest: request)!
        controller.matchmakerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKMatchmakerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let parent: MatchmakerView
        init(_ parent: MatchmakerView) { self.parent = parent }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            parent.onDismiss()
        }
        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            parent.onDismiss()
        }
        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            parent.onMatch(match)
        }
    }
}
