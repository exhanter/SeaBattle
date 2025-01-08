//
//  iPadMainViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//
import SwiftUI

struct iPadMainViewH: View {
    
    // Apple ID 6738694687
    
    @ObservedObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    @State private var showSettingsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                            .ignoresSafeArea(.container, edges: [.top, .horizontal])
                        HStack(spacing: 0) {
                            Spacer()
                            Image("war_ship8")
                                .resizable()
                                .scaledToFit()
                                .frame(height: geometry.size.height * 0.65)
                                .cornerRadius(geometry.size.width * 0.03)
                                .overlay(
                                        RoundedRectangle(cornerRadius: geometry.size.width * 0.03)
                                            .stroke(Color(red: 75/255, green: 56/255, blue: 42/255), lineWidth: 3)
                                    )
                            Spacer()
                            VStack {
                                Spacer()
                                Text("Sea Battle")
                                .font(.custom("Dorsa", size: geometry.size.height * 0.25))
                                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .shadow(color: .white, radius: 2)
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
                                .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.25, height: geometry.size.height * 0.12))
                                .shadow(color: .white, radius: 15)
                                .padding(.bottom, 5)
                                
                                Button("Settings") {
                                    self.showSettingsView = true
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .padding()
                                .padding(.horizontal, geometry.size.width * 0.1)
                                Spacer()
                                //Spacer(minLength: geometry.size.height * 0.15)
                            }
                            Spacer()
                        } // HStack off
                        .sheet(isPresented: $showSettingsView) { SettingsView(appState: appState)
                                .presentationDetents([.fraction(0.42)])
                        }
                        .ignoresSafeArea()
                    } //ZStack off
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    iPadMenuViewH(appState: appState, width: geometry.size.width, height: geometry.size.height)
                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
        }
    }
    init(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.appState = appState
        self.player = player
        self.enemy = enemy
        }
}


#Preview {
    iPadMainViewH(appState: AppState(), player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
}
