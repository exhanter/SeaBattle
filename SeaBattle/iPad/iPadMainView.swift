//
//  ContentViewIPad.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadMainView: View {
    // Apple ID 6738694687
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @ObservedObject var enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadMainViewV(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
                    .onAppear {
                        if self.enemyViewModel.appState.tempInstance {
                            enemyViewModel.appState = appState
                            enemyViewModel.player = player
                            enemyViewModel.enemy = enemy
                        }
                    }
            } else {
                iPadMainViewH(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
                    .onAppear {
                        enemyViewModel.appState = appState
                        enemyViewModel.player = player
                        enemyViewModel.enemy = enemy
                    }
            }
        }
    }
    
    init(player: PlayerData, enemy: PlayerData, enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel) {
        self.player = player
        self.enemy = enemy
        self.enemyViewModel = enemyViewModel
        UserDefaults.standard.register(defaults: [
            "musicOn": true,
            "soundOn": true
        ])
        }
}


#Preview {
    iPadMainView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), enemyViewModel:  EnemyFieldView.EnemyFieldViewViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP")))
        .environmentObject(AppState(tempInstance: true))
}
