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
    @State private var showNewGameOptions = false
    @State private var showContinueOptions = false

    // MARK: - Menu actions

    /// Start a fresh vs-computer match (arrange your fleet, then battle).
    private func startVsComputer() {
        appState.resetData(player: player, enemy: enemy)
        player.shipsRandomArrangement()
        enemy.shipsRandomArrangement()
        appState.selectedTab = .playerView
    }

    /// Resume the saved vs-computer match.
    private func continueVsComputer() {
        guard let snapshot = GameStore.load() else { return }
        snapshot.apply(to: appState, player: player, enemy: enemy)
        if appState.musicOn {
            AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
        }
        appState.selectedTab = .enemyView
    }

    /// Decide what "Continue" resumes: if both a vs-computer save and a
    /// hot-seat session exist, ask; otherwise go straight to the one present.
    private func continueGame() {
        let hasVsComputer = GameStore.hasSavedGame
        let hasHotSeat = HotSeatStore.hasSession
        if hasVsComputer && hasHotSeat {
            showContinueOptions = true
        } else if hasVsComputer {
            continueVsComputer()
        } else if hasHotSeat {
            appState.showHotSeat = true
        }
    }

    private func launchHotSeat() {
        if premiumManager.isPremium { appState.showHotSeat = true }
        else { appState.pendingPremiumIntent = .hotSeat; appState.showPaywall = true }
    }

    private func launchNearby() {
        if premiumManager.isPremium { appState.showNearby = true }
        else { appState.pendingPremiumIntent = .nearby; appState.showPaywall = true }
    }

    private func launchOnline() {
        if premiumManager.isPremium { appState.showOnline = true }
        else { appState.pendingPremiumIntent = .online; appState.showPaywall = true }
    }

    var body: some View {
        @Bindable var appState = appState
        return GeometryReader { geometry in
            ZStack {
                // No system TabView: it renders a tab bar (a floating, rounded
                // glass bar on newer iOS) that peeks out above our wooden
                // CustomTabView. Navigation is driven entirely by
                // appState.selectedTab + CustomTabView, so we switch content
                // ourselves and there is no system bar to hide.
                switch appState.selectedTab {
                case .menu:
                    ZStack {
                            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                            .ignoresSafeArea()
                        VStack(spacing: 0) {
                            Text("Sea Battle")
                                .font(.custom("Dorsa", size: geometry.size.width * 0.20))
                                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .shadow(color: .white, radius: 1)
                                .accessibility(identifier: "titleMainText")
                                .padding(.top, geometry.size.height * 0.13)

                            Spacer(minLength: geometry.size.height * 0.02)

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

                            Spacer(minLength: geometry.size.height * 0.03)

                            VStack(spacing: geometry.size.height * 0.02) {
                                // New game — choose the opponent type.
                                Button {
                                    if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                                    showNewGameOptions = true
                                } label: {
                                    Text("New game")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .accessibility(identifier: "newGameButton")
                                .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                                .shadow(color: .white, radius: 1, y: 1)

                                // Continue — shown only when a resumable game exists (a
                                // vs-computer save or a hot-seat session). Networked games
                                // can't be resumed once the app is closed.
                                if GameStore.hasSavedGame || HotSeatStore.hasSession {
                                    Button {
                                        if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                                        continueGame()
                                    } label: {
                                        Text("Continue game")
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                    }
                                    .accessibility(identifier: "continueGameButton")
                                    .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * 0.075, width: geometry.size.width * 0.8, height: geometry.size.height * 0.085))
                                    .shadow(color: .white, radius: 1, y: 1)
                                }
                            }

                            Spacer(minLength: geometry.size.height * 0.03)

                            // Settings — plain text link, not a wooden button.
                            Button {
                                self.showSettingsView = true
                            } label: {
                                Text("Settings")
                                    .font(.custom("Aldrich", size: geometry.size.width * 0.05))
                                    .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                                    .shadow(color: .black, radius: 1, y: 1)
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .accessibility(identifier: "settingsButton")
                            .padding(.bottom, geometry.size.height * 0.14)
                        } // VStack off
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .sheet(isPresented: $showSettingsView) { SettingsView()
                                .presentationDetents([.fraction(0.55)])
                        }
                        .confirmationDialog("New game", isPresented: $showNewGameOptions, titleVisibility: .visible) {
                            Button("Play vs computer") { startVsComputer() }
                            Button("Two players") { launchHotSeat() }
                            Button("Play online") { launchOnline() }
                            Button("Play nearby") { launchNearby() }
                            Button("Cancel", role: .cancel) { }
                        }
                        .confirmationDialog("Continue game", isPresented: $showContinueOptions, titleVisibility: .visible) {
                            Button("Play vs computer") { continueVsComputer() }
                            Button("Two players") { appState.showHotSeat = true }
                            Button("Cancel", role: .cancel) { }
                        }
                        .ignoresSafeArea()
                        } //ZStack off (menu)
                case .playerView:
                    PlayerFieldView(player: player, enemy: enemy)
                case .enemyView:
                    EnemyFieldView(player: player, enemy: enemy)
                case .about:
                    AboutView()
                case .iPadBattleView:
                    EmptyView() // iPad-only tab, never selected on iPhone
                } // switch off
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
            // Сетевые режимы — только в новой оболочке (R3.3); этот экран
            // больше не открывается и уходит в R4.6.
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
