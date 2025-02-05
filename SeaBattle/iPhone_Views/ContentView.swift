//
//  ContentView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

struct ContentView: View {
    
    // Apple ID 6738694687
    
    @StateObject private var appState = AppState(tempInstance: false)
    @StateObject private var player = PlayerData(name: "Player")
    @StateObject private var enemy = PlayerData(name: "Enemy")
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TabView(selection: $appState.selectedTab) {
                    ZStack {
                            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                            .ignoresSafeArea()
                        VStack(spacing: 0) {
                            Spacer(minLength: geometry.size.height * 0.10)
                            Text("Sea Battle")
                                .font(.custom("Dorsa", size: geometry.size.width * 0.22))
                                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .shadow(color: .white, radius: 1)
                                .padding(.bottom, 5)

                            Image("war_ship8")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width * 0.7)
                                .cornerRadius(geometry.size.width * 0.03)
                                .shadow(color: .white, radius: 3)
                                .overlay(
                                        RoundedRectangle(cornerRadius: geometry.size.width * 0.03)
                                            .stroke(Color(red: 75/255, green: 56/255, blue: 42/255), lineWidth: 3)
                                    )
                                
                            Spacer()
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                if !appState.gameIsActive {
                                    appState.resetData(player: player, enemy: enemy)
                                    player.shipsRandomArrangement()
                                    enemy.shipsRandomArrangement()
                                    appState.selectedTab = .playerView
                                } else if appState.gameIsActive {
                                    AppState.musicPlayer?.stop()
                                    appState.resetData(player: player, enemy: enemy)
                                }
                            } label: {
                                Text(appState.gameIsActive ? "Stop game" : "New game")
                            }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.8, height: geometry.size.height * 0.1))
                            .shadow(color: .white, radius: 1, y: 1)
                            .padding(.bottom, 5)
                            
                            
                            Button("Settings") {
                                self.showSettingsView = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .padding()
                            Spacer(minLength: geometry.size.height * 0.12)
                        } // VStack off
                        .sheet(isPresented: $showSettingsView) { SettingsView()
                                .presentationDetents([.fraction(0.42)])
                        }
                        .ignoresSafeArea()
                    } //ZStack off
                    .tag(AppState.SelectedTabs.menu)
                    PlayerFieldView(player: player, enemy: enemy)
                        .tag(AppState.SelectedTabs.playerView)
                    EnemyFieldView(player: player, enemy: enemy)
                        .tag(AppState.SelectedTabs.enemyView)
                    AboutView()
                        .tag(AppState.SelectedTabs.about)
                } // TabView off
                VStack(spacing: 0) {
                    ZStack {
                        Image("wood")
                            .resizable()
                            .renderingMode(.original)
                            .frame(height: geometry.size.height * 0.10)
                        if appState.selectedTab == .playerView || appState.selectedTab == .enemyView {
                            GameScoreView(numberOfPlayersShipsDestroyed: player.numberShipsDestroyed, numberOfEnemyShipsDestroyed: enemy.numberShipsDestroyed)
                                .padding(.horizontal, geometry.size.width * 0.04)// 0.077
                        }
                    }
                    Spacer()
                    CustomTabView(relativeFontSize: geometry.size.width * 0.13, height: geometry.size.height * 0.11)

                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
            .environmentObject(appState)
        }
    }
	
}

#Preview {
    ContentView()
}
