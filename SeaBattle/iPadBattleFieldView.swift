//
//  iPadBattleFieldView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadBattleFieldView: View {
    
    @State private var manualShipArrangement = false
    @State private var leftTopPointOfGameField: CGPoint = .zero
    @State private var isBouncing = false
    @State private var isTapEnabled = false
    
    @ObservedObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @ObservedObject private var enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
//                    if geometry.size.width / geometry.size.height < 0.56 {
//                        Text("Player")
//                            .font(Font.custom("Aldrich", size: 48))
//                            .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
//                            .shadow(color: .black, radius: 3, x: 2, y: 2)
//                            .padding(.bottom, geometry.size.height * 0.02)
//                    }
                        ZStack {
                            VStack(spacing: 0) {
                                Spacer()
                                ForEach(1...10, id:\.self) { row in
                                    HStack(spacing: 0) {
                                        ForEach(1...10, id: \.self) { column in
                                            if manualShipArrangement {
                                                CellView(fireStrokeIsOn: player.fireStrokeArray[row - 1][column - 1], cellStatus: .unknown, cellWidth: geometry.size.width * 0.06)
                                                    .background(GeometryReader { geometryLocal in
                                                        Color.clear
                                                            .onAppear {
                                                                self.leftTopPointOfGameField = geometryLocal.frame(in: .global).origin
                                                                player.defineShipPositionsAsCGPoint(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.width * 0.06)
                                                            }
                                                    })
                                            } else {
                                                CellView(fireStrokeIsOn: player.fireStrokeArray[row - 1][column - 1], cellStatus: player.cells[row - 1][column - 1].cellStatus, cellWidth: geometry.size.width * 0.06)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                ZStack {
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
                                                        enemyViewModel.checkShipOnFire(row: row, column: column, target: enemy)
                                                        if appState.soundOn {
                                                            enemyViewModel.chooseSound(row: row - 1, column: column - 1)
                                                        }
                                                        if appState.enemysTurn {
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                                appState.selectedTab = .playerView
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                                    enemyViewModel.computerTurn()
                                                                }
                                                            }
                                                        }
                                                    } label: {
                                                        CellView(fireStrokeIsOn: enemy.fireStrokeArray[row - 1][column - 1], cellStatus: status, cellWidth: geometry.size.width * 0.06)
                                                    }
                                                    .buttonStyle(NoPressEffect())
                                                    .disabled(!appState.gameIsActive)
                                                    .disabled(appState.enemysTurn)
                                                }
                                            }
                                        }
                                    }
                                    if !appState.gameIsActive {
                                        Color.black.opacity(0.2)
//                                            .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7, alignment: .center)
//                                            .clipShape(RoundedRectangle(cornerRadius: geometry.size.width * 0.05))
                                        Button("Start") {
                                            if !appState.gameIsActive {
                                                if appState.musicOn {
                                                    AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                                                }
                                                appState.gameIsActive = true
                                                manualShipArrangement = false
                                            }
                                            if appState.soundOn {
                                                AppState.playSound(sound: "click_sound.wav")
                                            }
                                        }
                                        .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.3, height: geometry.size.height * 0.08))
                                    }
                                }
                            }
                        }
                        .padding(.bottom, geometry.size.height * 0.05)
                        .ignoresSafeArea()
                }
                .ignoresSafeArea()
                if player.showFinishGameAlert {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(0.4)
                        .onTapGesture {
                            appState.resetData(player: player, enemy: enemy)
                        }
                    WinAlertView(isPlayerWon: false, text: "Defeat!")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isTapEnabled = true
                            }
                            if appState.soundOn {
                                AppState.playSound(sound: "defeat_sound.wav")
                            }
                        }
                        .onTapGesture {
                            if isTapEnabled {
                                appState.resetData(player: player, enemy: enemy)
                                isTapEnabled = false
                            }
                        }
                }
                if manualShipArrangement {
                    ShipReplacementView(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.width * 0.06, player: player) // 0.09
                }
                HStack {
                    iPadMenuView(appState: appState, relativeFontSize: 35, width: geometry.size.width * 0.07, height: geometry.size.height * 0.3)
                        Spacer()
                    VStack(alignment: .trailing) {
                        Spacer()
                        Button {
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            manualShipArrangement.toggle()
                            appState.tabsBlocked.toggle()
                        } label: {
                            iPadButtonView(text: manualShipArrangement ? "Save" : "Change", cornerRadius: 13, screenSide: .right)
                        }
                            .disabled(appState.gameIsActive)
                            .disabled(player.shipIsDragging.contains(true))
                            .opacity(appState.gameIsActive ? 0.5 : 1)
                        .padding(.bottom)
                        Button {
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            player.clearShips()
                            player.shipsRandomArrangement()
                        } label: {
                            iPadButtonView(text: "Shuffle", cornerRadius: 13, screenSide: .right)
                        }
                            .disabled(appState.gameIsActive)
                            .disabled(player.shipIsDragging.contains(true))
                            .opacity(appState.gameIsActive ? 0.5 : 1)
                        Spacer()
                        Spacer()
                        Spacer()
                    }
                }
            } //ZStack off
            .statusBar(hidden: true)
        }
    }
    init(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.appState = appState
        self.enemy = enemy
        self.player = player
        self.enemyViewModel = EnemyFieldView.EnemyFieldViewViewModel(appState: appState, enemy: enemy, player: player)
    }
}

#Preview {
    iPadBattleFieldView(appState: AppState(), player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
}
