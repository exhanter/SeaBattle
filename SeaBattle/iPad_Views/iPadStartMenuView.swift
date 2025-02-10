//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct iPadStartMenuView: View {
    @StateObject private var appState = AppState(tempInstance: false)
    @StateObject private var player = PlayerData(name: "Player")
    @StateObject private var enemy = PlayerData(name: "Enemy")
    @StateObject private var gameLogicViewModel = GameLogicViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP"))

    var body: some View {
        Group {
            switch appState.selectedTab {
            case .menu:
                iPadMainView(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            case .iPadBattleView:
                iPadBattleView(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            case .about:
                iPadAboutView(player: player, enemy: enemy)
            default:
                iPadMainView(player: player, enemy: enemy, gameLogicViewModel: gameLogicViewModel)
            }
        }
        .environmentObject(appState)
    }
}
#Preview {
    iPadStartMenuView()
}
