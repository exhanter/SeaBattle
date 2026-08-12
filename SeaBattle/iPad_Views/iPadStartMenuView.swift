//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct iPadStartMenuView: View {
    @Environment(AppState.self) private var appState
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
    }
}
#Preview {
    iPadStartMenuView()
}
