//
//  iPadBattleView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadBattleView: View {
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @ObservedObject private var enemyViewModel: GameLogicViewModel
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadBattleViewV(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
            } else {
                iPadBattleViewH(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
            }
        }
    }
    init(player: PlayerData, enemy: PlayerData, enemyViewModel: GameLogicViewModel) {
        self.enemy = enemy
        self.player = player
        self.enemyViewModel = enemyViewModel
    }
}

#Preview {
    iPadBattleView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), enemyViewModel: GameLogicViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP")))
        .environmentObject(AppState(tempInstance: true))
}
