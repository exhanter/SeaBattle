//
//  ContentView.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 03/02/2024.
//

import SwiftUI

struct ContentView: View {
    
    @State private var enemy = PlayerData(name: "Enemy")
    @State private var player = PlayerData(name: "Player")
    
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
                                if player.soundIsOn {
                                    PlayerData.playSound(sound: "click2_sound.wav")
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
                            .padding()
                            Group {
                                Picker("Select Difficulty", selection: $player.difficultyLevel) {
                                    ForEach(PlayerData.DifficultyLevel.allCases, id: \.self) {
                                        Text("\($0)")
                                    }
                                }
                                .onChange(of: player.difficultyLevel) {
                                    if player.soundIsOn {
                                        PlayerData.playSound(sound: "click_sound.wav")
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.bottom, geometry.size.height * 0.01)
                                HStack {
                                    Toggle("Music", isOn: $player.musicIsOn)
                                        .padding(.horizontal)
                                        .onChange(of: player.musicIsOn) {
                                            if player.soundIsOn {
                                                PlayerData.playSound(sound: "click_sound.wav")
                                            }
                                            if player.musicIsOn && player.gameIsActive {
                                                PlayerData.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                                            } else {
                                                PlayerData.musicPlayer?.stop()
                                            }
                                                        }
                                    Toggle("Sound", isOn: $player.soundIsOn)
                                        .padding(.horizontal)
                                        .onChange(of: player.soundIsOn) {
                                            if player.soundIsOn {
                                                PlayerData.playSound(sound: "click_sound.wav")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, geometry.size.width * 0.1)
                            Spacer(minLength: geometry.size.height * 0.15)
                        } // VStack off
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
                            gameScoreView(player: player, enemy: enemy)
                                .padding(.horizontal, geometry.size.width * 0.077)
                        }
                    }
                    Spacer()
                    CustomTabView(player: player, height: geometry.size.height * 0.13)

                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
        }
    }
}

#Preview {
    ContentView()
}
