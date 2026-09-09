//
//  MyShipsView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2024.
//

import SwiftUI

struct PlayerFieldView: View {
    
    @State private var leftTopPointOfGameField: CGPoint = .zero
    
    @Environment(AppState.self) private var appState
    var player: PlayerData
    var enemy: PlayerData
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    
                    UpperLabelAndButtonView(player: player, width: geometry.size.width, height: geometry.size.height)
                        .padding(.bottom, geometry.size.height * 0.01)
                    
                    VStack(spacing: 0) {
                        PlayerSquareView(player: player, leftTopPointOfGameField: $leftTopPointOfGameField, width: geometry.size.width * 0.09)
                    }
                    .padding(.bottom, geometry.size.height * 0.05)
                    
                    // Hidden via opacity (not removed) so its space stays reserved
                    // and the board doesn't shift down when the game ends — mirrors
                    // how "FIRE!" is kept in place in EnemyFieldView.
                    YourTurnButtonView(width: geometry.size.width, height: geometry.size.height)
                        .opacity(appState.gameIsOver ? 0 : 1)
                        .allowsHitTesting(!appState.gameIsOver)
                }
                .ignoresSafeArea()
                
                if player.showFinishGameAlert {
                    WinAlertView(
                        didPlayerWin: false,
                        onPlayAgain: {
                            appState.resetData(player: player, enemy: enemy)
                            player.shipsRandomArrangement()
                            enemy.shipsRandomArrangement()
                            appState.selectedTab = .playerView
                        },
                        onMenu: { appState.resetData(player: player, enemy: enemy) },
                        alignBottom: true,
                        bottomInset: geometry.size.height * 0.15
                    )
                    .accessibility(identifier: "winAlert")
                }
                if appState.manualShipArrangement {
                    ShipReplacementView(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.width * 0.09, player: player)
                }
            } //ZStack off
            .statusBar(hidden: true)
        }
    }
    init(player: PlayerData, enemy: PlayerData) {
        self.enemy = enemy
        self.player = player
    }
}

#Preview {
    PlayerFieldView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
        .environment(AppState())
}
