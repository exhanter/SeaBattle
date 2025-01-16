//
//  iPadMainViewV.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadMainViewV: View {
    
    // Apple ID 6738694687
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @ObservedObject private var enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                            .ignoresSafeArea(.container, edges: [.top, .horizontal])
                        VStack(spacing: 0) {
                            Spacer(minLength: geometry.size.height * 0.10)
                            Text("Sea Battle")
                                .font(.custom("Dorsa", size: geometry.size.width * 0.25))
                                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .shadow(color: .white, radius: 2)
                            Spacer(minLength: geometry.size.height * 0.02)
                            Image("war_ship8")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width * 0.6)
                                .clipped()
                                .cornerRadius(geometry.size.width * 0.03)
                                .overlay(
                                        RoundedRectangle(cornerRadius: geometry.size.width * 0.03)
                                            .stroke(Color(red: 75/255, green: 56/255, blue: 42/255), lineWidth: 3)
                                    )
                                .padding(.bottom, geometry.size.height * 0.02)
                            Spacer()
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
                            .shadow(color: .white, radius: 15)
                            .padding(.bottom, 10)
                        
                            Button("Settings") {
                                self.showSettingsView = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .padding()
                            .padding(.horizontal, geometry.size.width * 0.1)
                            Spacer(minLength: geometry.size.height * 0.10)
                        } // VStack off
                        .sheet(isPresented: $showSettingsView) { SettingsView()
                                .presentationDetents([.fraction(0.42)])
                        }
                        .ignoresSafeArea()
                    } //ZStack off
                    .ignoresSafeArea()
                HStack {
                    iPadMenuViewV(width: geometry.size.width, height: geometry.size.height)
                    Spacer()
                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
        }
    }
    init(player: PlayerData, enemy: PlayerData, enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel) {
        self.player = player
        self.enemy = enemy
        self.enemyViewModel = enemyViewModel
        }
}


#Preview {
    iPadMainViewV(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), enemyViewModel: EnemyFieldView.EnemyFieldViewViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "TestE"), player: PlayerData(name: "TestP")))
        .environmentObject(AppState(tempInstance: true))
}

