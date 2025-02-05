//
//  MyShipsView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2024.
//

import SwiftUI

struct PlayerFieldView: View {
    
    @State private var manualShipArrangement = false
    @State private var leftTopPointOfGameField: CGPoint = .zero
    @State private var isBouncing = false
    @State private var isTapEnabled = false
    
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
                    if geometry.size.width / geometry.size.height < 0.56 {
                        Text("Player")
                            .font(Font.custom("Aldrich", size: 48))
                            .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .shadow(color: .black, radius: 1, y: 2)
                            .padding(.bottom, geometry.size.height * 0.02)
                    }
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                manualShipArrangement.toggle()
                                appState.tabsBlocked.toggle()
                            } label: {
                                Text(manualShipArrangement ? "Save" : "Change")
                            }
                            .buttonStyle(WoodenButton(radius: 11, fontSize: 20, width: geometry.size.width * 0.5, height: geometry.size.height * 0.05))// 35
                            .disabled(appState.gameIsActive)
                            .disabled(player.shipIsDragging.contains(true))
                            .shadow(color: appState.gameIsActive || player.shipIsDragging.contains(true) ? .clear : .white, radius: 1, y: 0.5)
                            .opacity(appState.gameIsActive || player.shipIsDragging.contains(true) ? 0.5 : 1)
                            .padding(.bottom, geometry.size.height * 0.01)
                        ZStack {
                            VStack(spacing: 0) {
                                ForEach(1...10, id:\.self) { row in
                                    HStack(spacing: 0) {
                                        ForEach(1...10, id: \.self) { column in
                                            if manualShipArrangement {
                                                CellView(fireStrokeIsOn: player.fireStrokeArray[row - 1][column - 1], cellStatus: .unknown, cellWidth: geometry.size.width * 0.09)
                                                    .background(GeometryReader { geometryLocal in
                                                        Color.clear
                                                            .onAppear {
                                                                self.leftTopPointOfGameField = geometryLocal.frame(in: .global).origin
                                                                player.defineShipPositionsAsCGPoint(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.width * 0.09)
                                                            }
                                                    })
                                            } else {
                                                CellView(fireStrokeIsOn: player.fireStrokeArray[row - 1][column - 1], cellStatus: player.cells[row - 1][column - 1].cellStatus, cellWidth: geometry.size.width * 0.09)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, geometry.size.height * 0.05)
                        .ignoresSafeArea()

                    Button {
                        self.isBouncing = false
                        if !appState.gameIsActive {
                            if appState.musicOn {
                                AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                            }
                            appState.gameIsActive = true
                            manualShipArrangement = false
                            appState.selectedTab = .enemyView
                        } else if appState.gameIsActive {
                            appState.selectedTab = .enemyView
                        }
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                    } label: {
                        Text(appState.gameIsActive ? "Your turn!" : "Start")
                    }
                    .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.8, height: geometry.size.height * 0.1))
                    .disabled(appState.enemysTurn)
                    .disabled(appState.tabsBlocked)
                    .shadow(color: appState.enemysTurn || appState.tabsBlocked ? .clear : .white, radius: 1, y: 1)
                    .opacity(appState.enemysTurn || appState.tabsBlocked ? 0.5 : 1)
                    .padding(.bottom, geometry.size.height * 0.15)
                    .onChange(of: appState.enemysTurn) { newValue in
                        if newValue == false {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                if appState.selectedTab == .playerView {
                                    withAnimation(.spring(duration: 0.3, bounce: 0.9, blendDuration: 0).repeatCount(1, autoreverses: false)) {
                                        self.isBouncing = true
                                    }
                                }
                            }
                        }
                    }
                    .scaleEffect(self.isBouncing ? 1.05 : 1)
                }
                .ignoresSafeArea()
                if player.showFinishGameAlert {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(0.4)
                        .onTapGesture {
                            appState.resetData(player: player, enemy: enemy)
                        }
                    WinAlertView(isPlayerWon: false)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
