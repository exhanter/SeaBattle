//
//  MyShipsView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2024.
//

import SwiftUI

struct PlayerFieldView: View {
    
    @State private var leftTopPointOfGameField: CGPoint = .zero
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    
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
                    
                    YourTurnButtonView(width: geometry.size.width, height: geometry.size.height)
                }
                .ignoresSafeArea()
                
                if player.showFinishGameAlert {
                    WinAlertView(didPlayerWin: false)
                        .onTapGesture {
                            if appState.isTapEnabled {
                                appState.resetData(player: player, enemy: enemy)
                                appState.isTapEnabled = false
                            }
                        }
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
        .environmentObject(AppState(tempInstance: true))
}
