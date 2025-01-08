//
//  iPadBattleView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadBattleView: View {
    
    @ObservedObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadBattleViewV(appState: appState, player: player, enemy: enemy)
            } else {
                iPadBattleViewH(appState: appState, player: player, enemy: enemy)
            }
        }
    }
    init(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.appState = appState
        self.enemy = enemy
        self.player = player
    }
}

#Preview {
    iPadBattleView(appState: AppState(), player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
}
