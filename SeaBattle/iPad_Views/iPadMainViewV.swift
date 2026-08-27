//
//  iPadMainViewV.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadMainViewV: View {
    
    // Apple ID 6738694687
    
    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    var player: PlayerData
    var enemy: PlayerData
    private var gameLogicViewModel: GameLogicViewModel
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                        .ignoresSafeArea()
                    ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        Text("Sea Battle")
                            .font(.custom("Dorsa", size: geometry.size.width * 0.22))
                            .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .shadow(color: .white, radius: 2)
                        Image("war_ship8")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.5)
                            .cornerRadius(geometry.size.width * 0.03)
                            .shadow(color: .white, radius: 3)
                            .overlay(
                                    RoundedRectangle(cornerRadius: geometry.size.width * 0.03)
                                        .stroke(Color(red: 75/255, green: 56/255, blue: 42/255), lineWidth: 3)
                                )
                        Button {
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            if !appState.gameIsActive {
                                appState.resetData(player: player, enemy: enemy)
                                player.shipsRandomArrangement()
                                enemy.shipsRandomArrangement()
                                appState.selectedTab = .iPadBattleView
                            } else if appState.gameIsActive {
                                AppState.musicPlayer?.stop()
                                appState.resetData(player: player, enemy: enemy)
                            }
                        } label: {
                            Text(appState.gameIsActive ? "Stop game" : "New game")
                        }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                            .shadow(color: .white, radius: 5)
                            .padding(.bottom, 10)
                        if !appState.gameIsActive && GameStore.hasSavedGame {
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                if let snapshot = GameStore.load() {
                                    snapshot.apply(to: appState, player: player, enemy: enemy)
                                    if appState.musicOn {
                                        AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                                    }
                                    appState.selectedTab = .iPadBattleView
                                }
                            } label: {
                                Text("Continue game")
                            }
                                .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                                .shadow(color: .white, radius: 5)
                                .padding(.bottom, 10)
                        }
                        Button {
                            if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                            if premiumManager.isPremium {
                                appState.showHotSeat = true
                            } else {
                                appState.pendingPremiumIntent = .hotSeat
                                appState.showPaywall = true
                            }
                        } label: {
                            Text("Two players")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                            .shadow(color: .white, radius: 5)
                            .padding(.bottom, 10)

                        Button {
                            if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                            if premiumManager.isPremium { appState.showNearby = true } else { appState.pendingPremiumIntent = .nearby; appState.showPaywall = true }
                        } label: {
                            Text("Play nearby")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                            .shadow(color: .white, radius: 5)
                            .padding(.bottom, 10)

                        Button {
                            if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                            if premiumManager.isPremium { appState.showOnline = true } else { appState.pendingPremiumIntent = .online; appState.showPaywall = true }
                        } label: {
                            Text("Play online")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                            .shadow(color: .white, radius: 5)
                            .padding(.bottom, 10)

                        Button {
                            self.showSettingsView = true
                        } label: {
                            Text("Settings")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                            .shadow(color: .white, radius: 5)
                    } // VStack off
                    .frame(maxWidth: .infinity)
                    .padding(.top, geometry.size.height * 0.06)
                    .padding(.bottom, geometry.size.height * 0.06)
                    } // ScrollView off
                    .sheet(isPresented: $showSettingsView) { SettingsView()
                            .presentationDetents([.fraction(0.58)])
                    }
                } //ZStack off
                .ignoresSafeArea()
                HStack {
                    iPadMenuViewV(width: geometry.size.width, height: geometry.size.height)
                    Spacer()
                }
                .statusBar(hidden: true)
            }
        }
    }
    init(player: PlayerData, enemy: PlayerData, gameLogicViewModel: GameLogicViewModel) {
        self.player = player
        self.enemy = enemy
        self.gameLogicViewModel = gameLogicViewModel
        }
}


#Preview {
    iPadMainViewV(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel())
        .environment(AppState())
        .environment(PremiumManager())
}

