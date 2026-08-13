//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct iPadStartMenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = PlayerData(name: "Player")
    @State private var enemy = PlayerData(name: "Enemy")
    @State private var gameLogicViewModel = GameLogicViewModel()

    var body: some View {
        @Bindable var appState = appState
        return Group {
            switch appState.selectedTab {
            case .menu:
                iPadMainView(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            case .iPadBattleView:
                iPadBattleView(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            case .about:
                iPadAboutView()
            default:
                iPadMainView(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Persist when leaving the app mid-game, at a stable point.
            if phase != .active && appState.gameIsActive && !appState.enemysTurn {
                GameStore.save(GameSnapshot(appState: appState, player: player, enemy: enemy))
            }
        }
        // Presented at the stable root so the covers survive the menu/battle
        // view switching (fixes the iPad hot-seat dismissal).
        .fullScreenCover(isPresented: $appState.showHotSeat) { HotSeatContainerView() }
        .sheet(isPresented: $appState.showPaywall) { PaywallView() }
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            if isPremium && appState.pendingHotSeat {
                appState.pendingHotSeat = false
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.4))
                    appState.showHotSeat = true
                }
            }
        }
        .onChange(of: appState.showPaywall) { _, shown in
            if !shown && !premiumManager.isPremium { appState.pendingHotSeat = false }
        }
    }
}
#Preview {
    iPadStartMenuView()
}
