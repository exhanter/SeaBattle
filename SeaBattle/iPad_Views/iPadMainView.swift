//
//  ContentViewIPad.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadMainView: View {
    // Apple ID 6738694687
    
    @Environment(AppState.self) private var appState
    var player: PlayerData
    var enemy: PlayerData
    var gameLogicViewModel: GameLogicViewModel
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadMainViewV(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
                    .onAppear {
                        if !gameLogicViewModel.isConfigured {
                            gameLogicViewModel.configure(appState: appState, enemy: enemy, player: player)
                        }
                    }
            } else {
                iPadMainViewH(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
                    .onAppear {
                        if !gameLogicViewModel.isConfigured {
                            gameLogicViewModel.configure(appState: appState, enemy: enemy, player: player)
                        }
                    }
            }
        }
    }
    
    init(player: PlayerData, enemy: PlayerData, gameLogicViewModel: GameLogicViewModel) {
        self.player = player
        self.enemy = enemy
        self.gameLogicViewModel = gameLogicViewModel
        UserDefaults.standard.register(defaults: [
            "musicOn": true,
            "soundOn": true
        ])
        }
}


#Preview {
    iPadMainView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), gameLogicViewModel:  GameLogicViewModel())
        .environment(AppState())
}
