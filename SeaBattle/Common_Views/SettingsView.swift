//
//  SettingsView.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 04/12/2024.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    @State private var showPaywall = false
    @State private var showStats = false

    var body: some View {
        @Bindable var appState = appState
        return ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
                ScrollView {
                VStack() {
                    Text("Settings")
                        .font(.title)
                        .foregroundColor(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .padding(10)
                    Picker("Select language", selection: $appState.language) {
                        Text("English").tag("EN")
                        Text("Nederlands").tag("NL")
                        Text("System").tag(Locale.current.identifier)
                    }
                    .onChange(of: appState.language) {
                        UserDefaults.standard.set(appState.language, forKey: "Language")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Picker("Select Difficulty", selection: $appState.difficulty) {
                        ForEach([2, 1, 0, 3], id: \.self) {
                            switch $0 {
                            case 2:
                                Text("Easy")
                            case 1:
                                Text("Medium")
                            case 0:
                                Text("Hard")
                            case 3:
                                Text("Expert")
                            default:
                                Text("Unknown")
                            }
                        }
                    }
                    .onChange(of: appState.difficulty) { oldValue, newValue in
                        // Expert is a premium feature: bounce non-subscribers to
                        // the paywall and revert the selection.
                        if newValue == 3 && !premiumManager.isPremium {
                            appState.difficulty = oldValue == 3 ? 0 : oldValue
                            appState.pendingPremiumIntent = .expert // switch to Expert after subscribing
                            showPaywall = true
                            return
                        }
                        UserDefaults.standard.set(appState.difficulty, forKey: "difficulty")
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                    }
                    .disabled(appState.gameIsActive)
                    .pickerStyle(.segmented)
                    .padding()
                    Toggle("Music", isOn: $appState.musicOn)
                        .onChange(of: appState.musicOn) {
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            if appState.musicOn && appState.gameIsActive {
                                AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                            } else {
                                AppState.stopMusic()
                            }
                            UserDefaults.standard.set(appState.musicOn, forKey: "musicOn")
                        }
                        .padding()
                    Toggle("Sound", isOn: $appState.soundOn)
                        .onChange(of: appState.soundOn) {
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            UserDefaults.standard.set(appState.soundOn, forKey: "soundOn")
                        }
                        .padding()

                    Toggle("Reveal empty cells around sunk ships", isOn: $appState.autoRevealAroundSunk)
                        .onChange(of: appState.autoRevealAroundSunk) {
                            UserDefaults.standard.set(appState.autoRevealAroundSunk, forKey: "autoRevealAroundSunk")
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                        }
                        .padding(.horizontal)

                    // R2.1a: настройка из спеки 4.11. Стоит на старом экране,
                    // потому что новый приходит только в R4.2, а без неё шаг
                    // выбора уровня нечем выключить. Само значение хранит
                    // `AppState`, поэтому писать `UserDefaults` тут не надо.
                    Toggle("Ask for the level before a match", isOn: $appState.askLevelBeforeMatch)
                        .padding(.horizontal)
                        .padding(.bottom)

                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        showStats = true
                    } label: {
                        Label("Statistics", systemImage: "chart.bar.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                    .padding(.top)

                    if premiumManager.isPremium {
                        Label("Premium active", systemImage: "checkmark.seal.fill")
                            .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .padding()
                    } else {
                        Button {
                            if appState.soundOn {
                                AppState.playSound(sound: "click_sound.wav")
                            }
                            showPaywall = true
                        } label: {
                            Label("Go Premium", systemImage: "star.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
                .italic()
                .padding(20)
                }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: showPaywall) { _, shown in
            // Cancelled without subscribing → drop the pending Expert switch.
            if !shown && !premiumManager.isPremium { appState.pendingPremiumIntent = nil }
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(PremiumManager())
}
