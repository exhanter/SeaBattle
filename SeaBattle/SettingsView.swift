//
//  SettingsView.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 04/12/2024.
//

import SwiftUI

struct SettingsView: View {
    
    @ObservedObject var appState: AppState
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
                VStack() {
                    Text("Settings")
                        .font(.title)
                        .foregroundColor(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .padding(10)
                    Picker("Select Difficulty", selection: $appState.difficulty) {
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
                    .onChange(of: appState.difficulty) { _ in
                        UserDefaults.standard.set(appState.difficulty, forKey: "difficulty")
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                    }
                    .disabled(appState.gameIsActive)
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    Toggle("Music", isOn: $appState.musicOn)
                        .onChange(of: appState.musicOn) { _ in
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            if appState.musicOn && appState.gameIsActive {
                                AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                            } else {
                                AppState.musicPlayer?.stop()
                            }
                            UserDefaults.standard.set(appState.musicOn, forKey: "musicOn")
                        }
                        .padding()
                    Toggle("Sound", isOn: $appState.soundOn)
                        .onChange(of: appState.soundOn) { _ in
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            UserDefaults.standard.set(appState.soundOn, forKey: "soundOn")
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
    SettingsView(appState: AppState())
}
