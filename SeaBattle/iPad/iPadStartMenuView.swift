//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct iPadStartMenuView: View {
    @StateObject private var appState = AppState()
    @StateObject private var player = PlayerData(name: "Player")
    @StateObject private var enemy = PlayerData(name: "Enemy")

    var body: some View {
        switch appState.selectedTab {
        case .menu:
            iPadMainView(appState: appState, player: player, enemy: enemy)
        case .iPadBattleFieldView:
            iPadBattleView(appState: appState, player: player, enemy: enemy)
        case .about:
            iPadAboutView(appState: appState)
        default:
            iPadMainView(appState: appState, player: player, enemy: enemy)
        }
    }
}
#Preview {
    iPadStartMenuView()
}
