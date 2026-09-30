//
//  OnlineGameView.swift
//  SeaBattle
//
//  Phase 5 (online): authenticate with Game Center and present the real-time
//  matchmaker. Since R3.3 the match itself runs in the new battle
//  (`NetMatch` on the shell route `.network`): this view only hands the found
//  `GKMatch` over.
//
//  ПЕРЕХОДНОЕ: поиск с радаром, приглашение по коду и «Нет соединения»
//  заменят этот экран в R3.3b.
//

import SwiftUI
import GameKit

private let onlineAccent = Color(red: 248/255, green: 255/255, blue: 0/255)

struct OnlineGameView: View {
    @Environment(\.dismiss) private var dismiss

    /// Соперник найден — партию дальше ведёт оболочка.
    var onMatch: (GKMatch) -> Void = { _ in }

    @State private var gc = GameCenterManager.shared
    @State private var showMatchmaker = false

    var body: some View {
        HotSeatChrome(title: "Play online", onClose: leave) { _ in
            VStack(spacing: 16) {
                ProgressView().tint(.white)
                Text(gc.isAuthenticated ? "Finding an opponent…" : "Signing in to Game Center…")
                    .foregroundColor(.white.opacity(0.85))
            }
        } bottomBar: { size in
            Button { leave() } label: {
                Text("Cancel")
                    .font(.custom("Dorsa", size: size.width * 0.13))
                    .foregroundColor(onlineAccent)
                    .shadow(color: .white, radius: 1)
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            gc.authenticate()
            if gc.isAuthenticated { showMatchmaker = true }
        }
        .onChange(of: gc.isAuthenticated) { _, ok in
            if ok { showMatchmaker = true }
        }
        .sheet(isPresented: authBinding) {
            if let vc = gc.authViewController { GameCenterVCPresenter(viewController: vc) }
        }
        .fullScreenCover(isPresented: $showMatchmaker) {
            MatchmakerView(onMatch: { match in
                showMatchmaker = false
                onMatch(match)
            }, onDismiss: {
                showMatchmaker = false
                leave()
            })
        }
    }

    private var authBinding: Binding<Bool> {
        Binding(get: { gc.authViewController != nil },
                set: { if !$0 { gc.authViewController = nil } })
    }

    private func leave() {
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

    // GameKit calls the matchmaker delegate back on the main thread, but the
    // protocol carries no isolation annotation. `@preconcurrency` on the
    // conformance lets the main-actor methods satisfy it, with a runtime check.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency GKMatchmakerViewControllerDelegate {
        let parent: MatchmakerView
        init(_ parent: MatchmakerView) { self.parent = parent }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            parent.onDismiss()
        }
        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: any Error) {
            parent.onDismiss()
        }
        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            parent.onMatch(match)
        }
    }
}
