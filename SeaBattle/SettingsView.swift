//
//  SettingsView.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 04/12/2024.
//

import SwiftUI

struct SettingsView: View {
    
    @State var player: PlayerData
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
                VStack() {
                    Text("Settings")
                        .font(.title)
                        .foregroundColor(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .padding(10)
                    Picker("Select Difficulty", selection: $player.difficulty) {
                        ForEach([2, 1, 0], id: \.self) {
                            switch $0 {
                            case 2:
                                Text("Easy")
                            case 1:
                                Text("Medium")
                            case 0:
                                Text("Hard")
                            default:
                                Text("Unknown")
                            }
                        }
                    }
                    .onChange(of: player.difficulty) { // .onChange(of: player.difficultyLevel) {
                        UserDefaults.standard.set(player.difficulty, forKey: "difficulty")
                        if player.soundOn {
                            PlayerData.playSound(sound: "click_sound.wav")
                        }
                    }
                    .disabled(player.gameIsActive)
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    Toggle("Music", isOn: $player.musicOn)
                        .onChange(of: player.musicOn) {
                            if player.soundOn {
                                PlayerData.playSound(sound: "click_sound.wav")
                            }
                            if player.musicOn && player.gameIsActive {
                                PlayerData.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                            } else {
                                PlayerData.musicPlayer?.stop()
                            }
                            UserDefaults.standard.set(player.musicOn, forKey: "musicOn")
                        }
                        .padding()
                    Toggle("Sound", isOn: $player.soundOn)
                        .onChange(of: player.soundOn) {
                            if player.soundOn {
                                PlayerData.playSound(sound: "click_sound.wav")
                            }
                            UserDefaults.standard.set(player.soundOn, forKey: "soundOn")
                        }
                        .padding()
                }
            .italic()
            .padding(20)
        }
        .statusBar(hidden: true)
    }
}

#Preview {
    SettingsView(player: PlayerData(name: "Player"))
}
