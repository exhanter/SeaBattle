//
//  ContentViewIPad.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct ContentViewIPad: View {
    
    // Apple ID 6738694687
    
    @StateObject private var appState = AppState()
    @StateObject private var player = PlayerData(name: "Player")
    @StateObject private var enemy = PlayerData(name: "Enemy")
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TabView(selection: $appState.selectedTab) {
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                            .ignoresSafeArea(.container, edges: [.top, .horizontal])
                        VStack(spacing: 0) {
                            Spacer(minLength: geometry.size.height * 0.10)
                            ArcButton(fontSize: geometry.size.width * 0.065)
                            Spacer(minLength: geometry.size.height * 0.02)
                            Image("warship8NB")
                            Spacer()
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                if !appState.gameIsActive {
                                    appState.resetData(player: player, enemy: enemy)
                                    player.shipsRandomArrangement()
                                    enemy.shipsRandomArrangement()
                                    appState.selectedTab = .iPadBattleFieldView
                                } else if appState.gameIsActive {
                                    AppState.musicPlayer?.stop()
                                    appState.resetData(player: player, enemy: enemy)
                                }
                            } label: {
                                Text(appState.gameIsActive ? "Stop game" : "New game")
                            }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                            .padding(.bottom, 5)
                            
                            
                            Button("Settings") {
                                self.showSettingsView = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .padding()
                            .padding(.horizontal, geometry.size.width * 0.1)
                            Spacer(minLength: geometry.size.height * 0.15)
                        } // VStack off
                        .sheet(isPresented: $showSettingsView) { SettingsView(appState: appState)
                                .presentationDetents([.fraction(0.42)])
                        }
                        .ignoresSafeArea()
                    } //ZStack off
                    .tag(AppState.SelectedTabs.menu)
                    iPadBattleFieldView(appState: appState, player: player, enemy: enemy)
                        .tag(AppState.SelectedTabs.iPadBattleFieldView)
                    AboutView(appState: appState)
                        .tag(AppState.SelectedTabs.about)
                } // TabView off
                //.toolbarVisibility(.hidden)
                //                VStack(spacing: 0) {
                //                    ZStack {
                //                        Image("wood")
                //                            .resizable()
                //                            .renderingMode(.original)
                //                            .frame(height: geometry.size.height * 0.08)
                //                        if appState.selectedTab == .playerView || appState.selectedTab == .enemyView {
                //                            GameScoreView(numberOfPlayersShipsDestroyed: player.numberShipsDestroyed, numberOfEnemyShipsDestroyed: enemy.numberShipsDestroyed)
                //                                .padding(.horizontal, geometry.size.width * 0.04)// 0.077
                //                        }
                //                    }
                //                    Spacer()
                //                    CustomTabView(appState: appState, relativeFontSize: geometry.size.width * 0.1, height: geometry.size.height * 0.08)
                //
                //                }
                HStack {
                    iPadMenuView(appState: appState, relativeFontSize: 35, width: geometry.size.width * 0.07, height: geometry.size.height * 0.3)
                    Spacer()
                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
        }
    }
    init() {
            UserDefaults.standard.register(defaults: [
                "musicOn": true,
                "soundOn": true
            ])
        }
}


#Preview {
    ContentViewIPad()
}
