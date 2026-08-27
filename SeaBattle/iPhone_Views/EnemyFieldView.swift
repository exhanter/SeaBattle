//
//  BattleFieldView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

struct EnemyFieldView: View {

    @Environment(AppState.self) private var appState
    var player: PlayerData
    var enemy: PlayerData
    @State private var gameLogicViewModel = GameLogicViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    // Changing element kept at the TOP so its show/hide is absorbed
                    // by the spacer above and never shifts the board (anchored below).
                    HintButton(gameLogicViewModel: gameLogicViewModel)
                        .padding(.bottom, geometry.size.height * 0.02)
                    if geometry.size.width / geometry.size.height < 0.56 {
                        Text("Opponent")
                            .font(Font.custom("Aldrich", size: 48))
                            .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .shadow(color: .black, radius: 3, x: 2, y: 2)
                            .padding(.bottom, geometry.size.height * 0.08)
                    }
                    
                    EnemySquareView(enemy: enemy, gameLogicViewModel: gameLogicViewModel, width: geometry.size.width * 0.09)
                    .padding(.bottom, geometry.size.height * 0.05)

                    Text("FIRE!")
                        .font(Font.custom("Aldrich", size: 40))
                        .foregroundStyle(Color(red: 255/255, green: 95/255, blue: 0/255))
                        .shadow(color: Color(red: 248/255, green: 255/255, blue: 0/255), radius: 2)
                        .frame(height: geometry.size.height * 0.1)
                        .padding(.bottom, geometry.size.height * 0.15)
                        .opacity(appState.gameIsActive ? 1 : 0)
                }
                .ignoresSafeArea()
                
                if enemy.showFinishGameAlert {
                    WinAlertView(
                        didPlayerWin: true,
                        onPlayAgain: {
                            appState.resetData(player: player, enemy: enemy)
                            player.shipsRandomArrangement()
                            enemy.shipsRandomArrangement()
                            appState.selectedTab = .playerView
                        },
                        onMenu: { appState.resetData(player: player, enemy: enemy) }
                    )
                }
            } //ZStack off
            .statusBar(hidden: true)
            .onAppear {
                if !gameLogicViewModel.isConfigured {
                    gameLogicViewModel.configure(appState: appState, enemy: enemy, player: player)
                }
            }
        }
    }
    
    init(player: PlayerData, enemy: PlayerData) {
        self.enemy = enemy
        self.player = player
    }
}

#Preview {
    EnemyFieldView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
        .environment(AppState())
        .environment(PremiumManager())
}
