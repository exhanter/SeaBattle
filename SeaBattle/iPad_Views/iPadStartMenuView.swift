//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct iPadStartMenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = PlayerData(name: "Player")
    @State private var enemy = PlayerData(name: "Enemy")
    @State private var gameLogicViewModel = GameLogicViewModel()

    var body: some View {
        Group {
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
    }
}
#Preview {
    iPadStartMenuView()
}
