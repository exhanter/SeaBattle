//
//  iPadBattleViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadBattleViewH: View {
    
    @State private var leftTopPointOfGameField: CGPoint = .zero
    let scaleForCells = 0.06
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @ObservedObject private var gameLogicViewModel: GameLogicViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
                VStack {
                    iPadGameScoreViewH(player: player, enemy: enemy, width: geometry.size.width, height: geometry.size.height)
                    Spacer()
                    iPadMenuViewH(width: geometry.size.width, height: geometry.size.height)
                }
                    .ignoresSafeArea()
                iPadShipArrangementMenuViewH(player: player, width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    VStack(spacing: 0) {
                        PlayerSquareView(player: player, leftTopPointOfGameField: $leftTopPointOfGameField, width: geometry.size.height * scaleForCells)
                    }
                    Spacer()
                    ZStack {
                        EnemySquareView(enemy: enemy, gameLogicViewModel: gameLogicViewModel, width: geometry.size.height * scaleForCells)
                        if !appState.gameIsActive {
                            iPadStartButton(width: geometry.size.height, height: geometry.size.width)
                        }
                    }
                    Spacer()
                }
                .ignoresSafeArea()
                if player.showFinishGameAlert || enemy.showFinishGameAlert {
                    WinAlertView(didPlayerWin: enemy.showFinishGameAlert ? true : false)
                        .onTapGesture {
                            if appState.isTapEnabled {
                                appState.resetData(player: player, enemy: enemy)
                                appState.isTapEnabled = false
                            }
                        }
                }
                if appState.manualShipArrangement {
                    ShipReplacementView(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.height * scaleForCells, player: player) // 0.09
                }

            } //ZStack off
            .statusBar(hidden: true)
        }
    }
    init(player: PlayerData, enemy: PlayerData, gameLogicViewModel: GameLogicViewModel) {
        self.enemy = enemy
        self.player = player
        self.gameLogicViewModel = gameLogicViewModel
    }
}

#Preview {
    iPadBattleViewH(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP")))
        .environmentObject(AppState(tempInstance: true))
}
