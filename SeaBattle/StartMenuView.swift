//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct StartMenuView: View {
    @StateObject private var appState = AppState()
    @StateObject private var player = PlayerData(name: "Player")
    @StateObject private var enemy = PlayerData(name: "Enemy")

    var body: some View {
        switch appState.selectedTab {
        case .menu:
            ContentViewIPad(appState: appState, player: player, enemy: enemy)
        case .iPadBattleFieldView:
            iPadBattleFieldView(appState: appState, player: player, enemy: enemy)
        case .about:
            AboutView(appState: appState)
        default:
            ContentViewIPad(appState: appState, player: player, enemy: enemy)
        }
    }
}
#Preview {
    StartMenuView()
}
