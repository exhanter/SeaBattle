//
//  StartMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 23/12/2024.
//

import SwiftUI

struct StartMenuView: View {
    @State private var selectedTab: AppState.SelectedTabs = .menu
    var body: some View {
        switch selectedTab {
        case .menu:
            ContentViewIPad()
        case .enemyView:
            EnemyFieldView()
        case .iPadBattleFieldView:
            iPadBattleFieldView()
        case .playerView:
            PlayerFieldView()
        case .about:
            AboutView()
        }
    }
}
menu, playerView, enemyView, about, iPadBattleFieldView
#Preview {
    StartMenuView()
}
