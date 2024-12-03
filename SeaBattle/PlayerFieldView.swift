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
    
    var enemy: PlayerData
    var player: PlayerData
    
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
                            .shadow(color: .black, radius: 3, x: 2, y: 2)
                            .padding(.bottom, geometry.size.height * 0.02)
                    }
                            Button {
                                if player.soundOn {
                                    PlayerData.playSound(sound: "click_sound.wav")
                                }
                                manualShipArrangement.toggle()
                                player.tabsBlocked.toggle()
                            } label: {
                                Text(manualShipArrangement ? "Save" : "Change")
                            }
                            .buttonStyle(WoodenButton(radius: 11, fontSize: 20, width: geometry.size.width * 0.5, height: geometry.size.height * 0.05))// 35
                            .disabled(player.gameIsActive)
                            .disabled(player.shipIsDragging.contains(true))
                            .opacity(player.gameIsActive ? 0.5 : 1)
                            .padding(.bottom, geometry.size.height * 0.01)
                        ZStack {
                            VStack(spacing: 0) {
                                ForEach(1...10, id:\.self) { row in
                                    HStack(spacing: 0) {
                                        ForEach(1...10, id: \.self) { column in
                                            if manualShipArrangement {
                                                CellView(player: player, row: row - 1, column: column - 1, cellStatus: .unknown, cellWidth: geometry.size.width * 0.09)
                                                    .background(GeometryReader { geometryLocal in
                                                        Color.clear
                                                            .onAppear {
                                                                self.leftTopPointOfGameField = geometryLocal.frame(in: .global).origin
                                                                player.defineShipPositionsAsCGPoint(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: geometry.size.width * 0.09)
                                                            }
                                                    })
                                            } else {
                                                CellView(player: player, row: row - 1, column: column - 1, cellStatus: player.cells[row - 1][column - 1].cellStatus, cellWidth: geometry.size.width * 0.09)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, geometry.size.height * 0.05)
                        .ignoresSafeArea()

                    Button {
                        isBouncing = false
                        if !player.gameIsActive {
                            if player.musicOn {
                                PlayerData.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                            }
                            player.gameIsActive = true
                            manualShipArrangement = false
                            player.selectedTab = .enemyView
                        } else if player.gameIsActive {
                            player.selectedTab = .enemyView
                        }
                        if player.soundOn {
                            PlayerData.playSound(sound: "click_sound.wav")
                        }
                    } label: {
                        Text(player.gameIsActive ? "Your turn!" : "Start")
                    }
                    .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.8, height: geometry.size.height * 0.1))
                    .disabled(player.enemysTurn)
                    .disabled(player.tabsBlocked)
                    .opacity(player.enemysTurn ? 0.5 : 1)
                    .opacity(player.tabsBlocked ? 0.5 : 1)
                    .padding(.bottom, geometry.size.height * 0.15)
                    .onChange(of: player.enemysTurn) { _, newValue in
                        if newValue == false {
                            withAnimation(.spring(duration: 0.3, bounce: 0.9, blendDuration: 0).repeatCount(1, autoreverses: false).delay(2)) {
                                isBouncing = true
                            }
                        }
                    }
                    .scaleEffect(isBouncing ? 1.05 : 1)
                }
                .ignoresSafeArea()
                if player.showFinishGameAlert {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(0.4)
                        .onTapGesture {
                            PlayerData.resetData(player: player, enemy: enemy)
                        }
                    WinAlertView(isPlayerWon: false, text: "Defeat!")
                        .onAppear {
                            if player.soundOn {
                                PlayerData.playSound(sound: "defeat_sound.wav")
                            }
                        }
                        .onTapGesture {
                            PlayerData.resetData(player: player, enemy: enemy)
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
}
