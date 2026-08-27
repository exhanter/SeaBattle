//
//  ContentView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

struct ContentView: View {
    
    // Apple ID 6738694687
    
    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = PlayerData(name: "Player")
    @State private var enemy = PlayerData(name: "Enemy")
    @State private var showSettingsView = false
    
    var body: some View {
        @Bindable var appState = appState
        return GeometryReader { geometry in
            ZStack {
                TabView(selection: $appState.selectedTab) {
                    ZStack {
                            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                            .ignoresSafeArea()
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                            Text("Sea Battle")
                                .font(.custom("Dorsa", size: geometry.size.width * 0.20))
                                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .shadow(color: .white, radius: 1)
                                .accessibility(identifier: "titleMainText")

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
                                    appState.selectedTab = .playerView
                                } else if appState.gameIsActive {
                                    AppState.musicPlayer?.stop()
                                    appState.resetData(player: player, enemy: enemy)
                                }
                            } label: {
                                Text(appState.gameIsActive ? "Stop game" : "New game")
                            }
                            .accessibility(identifier: "newOrStopGameButton")
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                            .shadow(color: .white, radius: 1, y: 1)

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
                                        appState.selectedTab = .enemyView
                                    }
                                } label: {
                                    Text("Continue game")
                                }
                                .accessibility(identifier: "continueGameButton")
                                .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                                .shadow(color: .white, radius: 1, y: 1)
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
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                            .shadow(color: .white, radius: 1, y: 1)

                            Button {
                                if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                                if premiumManager.isPremium { appState.showNearby = true } else { appState.pendingPremiumIntent = .nearby; appState.showPaywall = true }
                            } label: {
                                Text("Play nearby")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                            .shadow(color: .white, radius: 1, y: 1)

                            Button {
                                if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                                if premiumManager.isPremium { appState.showOnline = true } else { appState.pendingPremiumIntent = .online; appState.showPaywall = true }
                            } label: {
                                Text("Play online")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                            .shadow(color: .white, radius: 1, y: 1)

                            Button {
                                self.showSettingsView = true
                            } label: {
                                Text("Settings")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                            .shadow(color: .white, radius: 1, y: 1)
                            } // VStack off
                            .frame(maxWidth: .infinity)
                            .padding(.top, geometry.size.height * 0.13)
                            .padding(.bottom, geometry.size.height * 0.16)
                        }
                        .sheet(isPresented: $showSettingsView) { SettingsView()
                                .presentationDetents([.fraction(0.55)])
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
            .onChange(of: scenePhase) { _, phase in
                // Persist when leaving the app mid-game, at a stable point.
                if phase != .active && appState.gameIsActive && !appState.enemysTurn {
                    GameStore.save(GameSnapshot(appState: appState, player: player, enemy: enemy))
                }
                // Pull the latest synced data when returning to the foreground.
                if phase == .active {
                    Task { await CloudSyncManager.shared.refresh() }
                }
            }
            .fullScreenCover(isPresented: $appState.showHotSeat) {
                HotSeatContainerView()
            }
            .fullScreenCover(isPresented: $appState.showNearby) {
                NearbyGameView()
            }
            .fullScreenCover(isPresented: $appState.showOnline) {
                OnlineGameView()
            }
            .sheet(isPresented: $appState.showPaywall) {
                PaywallView()
            }
            .onChange(of: premiumManager.isPremium) { _, isPremium in
                // Finish whatever the user was doing when the paywall opened.
                guard isPremium, let intent = appState.pendingPremiumIntent else { return }
                appState.pendingPremiumIntent = nil
                switch intent {
                case .expert:
                    appState.difficulty = 3
                    UserDefaults.standard.set(3, forKey: "difficulty")
                case .hotSeat, .nearby, .online:
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4)) // let the paywall dismiss first
                        switch intent {
                        case .hotSeat: appState.showHotSeat = true
                        case .nearby: appState.showNearby = true
                        case .online: appState.showOnline = true
                        case .expert: break
                        }
                    }
                }
            }
            .onChange(of: appState.showPaywall) { _, shown in
                if !shown && !premiumManager.isPremium { appState.pendingPremiumIntent = nil }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(PremiumManager())
}
