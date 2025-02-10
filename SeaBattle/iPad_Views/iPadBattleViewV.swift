//
//  iPadBattleFieldView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadBattleViewV: View {
    
    //@State private var manualShipArrangement = false
    @State private var leftTopPointOfGameField: CGPoint = .zero
    @State private var isBouncing = false
    @State private var isTapEnabled = false
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
                HStack {
                    VStack(alignment: .leading) {
                        ZStack(alignment: .leading) {
                            iPadMenuButtonsViewV(width: geometry.size.width, height: geometry.size.height)
                                VStack(alignment: .leading) {
                                    Text("Ships:")
                                        .font(.custom("Dorsa", size: geometry.size.width * 0.07))
                                        .foregroundStyle(.white)
                                        .padding(.bottom, 5)
                    
                                    Button {
                                        if appState.soundOn {
                                            AppState.playSound(sound: "click_sound.wav")
                                        }
                                        appState.manualShipArrangement.toggle()
                                        appState.tabsBlocked.toggle()
                                    }
                                    label: {
                                        Text("Change")
                                            .font(.custom("Dorsa", size: geometry.size.width * 0.06))
                                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                            .fixedSize(horizontal: true, vertical: true)
                                            .shadow(color: appState.manualShipArrangement ? .white : .clear, radius: 5)
                                    }
                                    .padding(.bottom, 2)
                                    .disabled(appState.gameIsActive)
                                    .disabled(player.shipIsDragging.contains(true))
                                    .opacity(appState.gameIsActive ? 0.5 : 1)
                                    Button {
                                        if appState.soundOn {
                                            AppState.playSound(sound: "click_sound.wav")
                                        }
                                        player.clearShips()
                                        player.shipsRandomArrangement()
                                    }
                                    label: {
                                        Text("Shuffle")
                                            .font(.custom("Dorsa", size: geometry.size.width * 0.06))
                                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                            .fixedSize(horizontal: true, vertical: true)
                                    }
                                    .disabled(appState.tabsBlocked)
                                    .disabled(appState.gameIsActive)
                                    .disabled(player.shipIsDragging.contains(true))
                                    .opacity(appState.gameIsActive ? 0.5 : 1)
                                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                                }
                                .padding(.leading, geometry.size.width * 0.0132)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                        ZStack {
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
                        }
                        .ignoresSafeArea()
                }
                .ignoresSafeArea()
                if player.showFinishGameAlert || enemy.showFinishGameAlert {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(0.4)
                        .onTapGesture {
                            appState.resetData(player: player, enemy: enemy)
                        }
                    WinAlertView(isPlayerWon: enemy.showFinishGameAlert ? true : false)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isTapEnabled = true
                            }
                            if appState.soundOn {
                                AppState.playSound(sound: player.showFinishGameAlert ? "defeat_sound.wav" : "victory_sound.wav")
                            }
                        }
                        .onTapGesture {
                            if isTapEnabled {
                                appState.resetData(player: player, enemy: enemy)
                                isTapEnabled = false
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
