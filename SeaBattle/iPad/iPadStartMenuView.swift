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
    @ObservedObject private var enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel

    var body: some View {
        Group {
            switch appState.selectedTab {
            case .menu:
                iPadMainView(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
            case .iPadBattleView:
                iPadBattleView(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
            case .about:
                iPadAboutView()
            default:
                iPadMainView(player: player, enemy: enemy, enemyViewModel: enemyViewModel)
            }
        }
        .environmentObject(appState)
    }
    init() {
        self.enemyViewModel = EnemyFieldView.EnemyFieldViewViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP"))
    }
}
#Preview {
    iPadStartMenuView()
}
