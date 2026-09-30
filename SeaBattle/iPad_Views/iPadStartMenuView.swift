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
            if phase == .active {
                Task { await CloudSyncManager.shared.refresh() }
            }
        }
        // Presented at the stable root so the covers survive the menu/battle
        // view switching (fixes the iPad hot-seat dismissal).
        .fullScreenCover(isPresented: $appState.showHotSeat) { HotSeatContainerView() }
        // Сетевые режимы — только в новой оболочке (R3.3).
        .sheet(isPresented: $appState.showPaywall) { PaywallView() }
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            guard isPremium, let intent = appState.pendingPremiumIntent else { return }
            appState.pendingPremiumIntent = nil
            switch intent {
            case .expert:
                appState.difficulty = 3
                UserDefaults.standard.set(3, forKey: "difficulty")
            case .hotSeat, .nearby, .online:
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.4))
                    switch intent {
                    case .hotSeat: appState.showHotSeat = true
                    case .nearby: appState.showNearby = true
                    case .online: appState.showOnline = true
                    case .expert: break
                    }
                }
            }
        }
        .onChange(of: appState.showPaywall) { _, shown in
            if !shown && !premiumManager.isPremium { appState.pendingPremiumIntent = nil }
        }
    }
}
#Preview {
    iPadStartMenuView()
}
