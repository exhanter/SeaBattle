//
//  ContentViewIPad.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadMainView: View {
    // Apple ID 6738694687
    
    @ObservedObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadMainViewV(appState: appState, player: player, enemy: enemy)
            } else {
                iPadMainViewH(appState: appState, player: player, enemy: enemy)
            }
        }
    }
    
    init(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.appState = appState
        self.player = player
        self.enemy = enemy
        UserDefaults.standard.register(defaults: [
            "musicOn": true,
            "soundOn": true
        ])
        }
}


#Preview {
    iPadMainView(appState: AppState(), player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
}
