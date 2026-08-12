//
//  iPadBattleView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadBattleView: View {
    
    @Environment(AppState.self) private var appState
    var player: PlayerData
    var enemy: PlayerData
    private var gameLogicViewModel: GameLogicViewModel
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadBattleViewV(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            } else {
                iPadBattleViewH(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            }
        }
    }
    init(player: PlayerData, enemy: PlayerData, gameLogicViewModel: GameLogicViewModel) {
        self.enemy = enemy
        self.player = player
        self.gameLogicViewModel = gameLogicViewModel
    }
}

#Preview {
    iPadBattleView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel())
        .environment(AppState())
}
