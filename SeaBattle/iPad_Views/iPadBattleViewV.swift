//
//  iPadBattleFieldView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadBattleViewV: View {
    
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
                HStack {
                    iPadMenuViewV(width: geometry.size.width, height: geometry.size.height)
                    Spacer()
                    iPadGameScoreViewV(player: player, enemy: enemy, width: geometry.size.width)
                    .padding(.trailing, geometry.size.width * 0.03)//0.0132
                } //HStack off
                iPadShipArrangementMenuViewV(player: player, width: geometry.size.width, height: geometry.size.height)
                VStack(spacing: 0) {
                    Spacer()
                    PlayerSquareView(player: player, leftTopPointOfGameField: $leftTopPointOfGameField, width: geometry.size.width * scaleForCells)
                    Spacer()
                    ZStack {
                        EnemySquareView(enemy: enemy, gameLogicViewModel: gameLogicViewModel, width: geometry.size.width * scaleForCells)
                        if !appState.gameIsActive {
                            iPadStartButton(width: geometry.size.width, height: geometry.size.height)
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
                    ShipReplacementView(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.width * scaleForCells, player: player) // 0.09
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
    iPadBattleViewV(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP")))
        .environmentObject(AppState(tempInstance: true))
}
