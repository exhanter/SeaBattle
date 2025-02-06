//
//  BattleFieldView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

struct EnemyFieldView: View {
    
    @State private var isVisible = true
    @State private var isTapEnabled = false
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @StateObject private var gameLogicViewModel = GameLogicViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP"))
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    if geometry.size.width / geometry.size.height < 0.56 {
                        Text("Opponent")
                            .font(Font.custom("Aldrich", size: 48))
                            .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .shadow(color: .black, radius: 3, x: 2, y: 2)
                            .padding(.bottom, geometry.size.height * 0.08)
                    }
                    VStack(spacing: 0) {
                        ForEach(1...10, id:\.self) { row in
                            HStack(spacing: 0) {
                                ForEach(1...10, id: \.self) { column in
                                    let status = enemy.cells[row - 1][column - 1].cellStatus
                                    Button {
                                        enemy.fireStrokeArray[row - 1][column - 1] = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                enemy.fireStrokeArray[row - 1][column - 1] = false
                                        }
                                        gameLogicViewModel.checkShipOnFire(row: row, column: column, target: enemy)
                                        if appState.soundOn {
                                            gameLogicViewModel.chooseSound(row: row - 1, column: column - 1)
                                        }
                                        if appState.enemysTurn {
                                           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                               appState.selectedTab = .playerView
                                               DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                   gameLogicViewModel.computerTurn()
                                               }
                                           }
                                        }
                                    } label: {
                                        CellView(fireStrokeIsOn: enemy.fireStrokeArray[row - 1][column - 1], cellStatus: status, cellWidth: geometry.size.width * 0.09)
                                    }
                                    .buttonStyle(NoPressEffect())
                                    .disabled(!appState.gameIsActive)
                                    .disabled(appState.enemysTurn)
                                }
                            }
                        }
                    }
                    .ignoresSafeArea()
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
                    Color.black
                        .ignoresSafeArea()
                        .opacity(0.4)
                        .onTapGesture {
                            appState.resetData(player: player, enemy: enemy)
                        }
                    WinAlertView(isPlayerWon: true)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isTapEnabled = true
                            }
                            if appState.soundOn {
                                AppState.playSound(sound: "victory_sound.wav")
                            }
                        }
                        .onTapGesture {
                            if isTapEnabled {
                                appState.resetData(player: player, enemy: enemy)
                                isTapEnabled = false
                            }
                        }
                }
            } //ZStack off
            .statusBar(hidden: true)
            .onAppear {
                if self.gameLogicViewModel.appState.tempInstance {
                    self.gameLogicViewModel.appState = self.appState
                    self.gameLogicViewModel.player = self.player
                    self.gameLogicViewModel.enemy = self.enemy
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
        .environmentObject(AppState(tempInstance: true))
}
