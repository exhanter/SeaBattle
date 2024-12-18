//
//  ContentView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

struct ContentView: View {
    
    // Apple ID 6738694687
    
    @StateObject private var enemy = PlayerData(name: "Enemy")
    @StateObject private var player = PlayerData(name: "Player")
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TabView(selection: $player.selectedTab) {
                    ZStack {
                            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                                .ignoresSafeArea(.container, edges: [.top, .horizontal])
                        VStack(spacing: 0) {
                            Spacer(minLength: geometry.size.height * 0.10)
                            ArcButton(fontSize: geometry.size.width * 0.13)
                            Spacer(minLength: geometry.size.height * 0.02)
                            Image("warship8NB")
                            Spacer()
                            Button {
                                print(geometry.size.width)
                                if player.soundOn {
                                    PlayerData.playSound(sound: "click_sound.wav")
                                }
                                if !player.gameIsActive {
                                    PlayerData.resetData(player: player, enemy: enemy)
                                    player.shipsRandomArrangement()
                                    enemy.shipsRandomArrangement()
                                    player.selectedTab = .playerView
                                } else if player.gameIsActive {
                                    PlayerData.musicPlayer?.stop()
                                    PlayerData.resetData(player: player, enemy: enemy)
                                }
                            } label: {
                                Text(player.gameIsActive ? "Stop game" : "New game")
                            }
                            .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.8, height: geometry.size.height * 0.1))
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
                        .sheet(isPresented: $showSettingsView) { SettingsView(player: player)
                                .presentationDetents([.fraction(0.42)])
                        }
                        .ignoresSafeArea()
                    } //ZStack off
                        .tag(PlayerData.SelectedTabs.menu)
                    PlayerFieldView(player: player, enemy: enemy)
                        .tag(PlayerData.SelectedTabs.playerView)
                    EnemyFieldView(player: player, enemy: enemy)
                        .tag(PlayerData.SelectedTabs.enemyView)
                    AboutView()
                        .tag(PlayerData.SelectedTabs.about)
                } // TabView off
                VStack(spacing: 0) {
                    ZStack {
                        Image("wood")
                            .resizable()
                            .renderingMode(.original)
                            .frame(height: geometry.size.height * 0.10)
                        if player.selectedTab == .playerView || player.selectedTab == .enemyView {
                            GameScoreView(player: player, enemy: enemy)
                                .padding(.horizontal, geometry.size.width * 0.04)// 0.077
                        }
                    }
                    Spacer()
                    CustomTabView(player: player, relativeFornSize: geometry.size.width * 0.13, height: geometry.size.height * 0.13)

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
    ContentView()
}
