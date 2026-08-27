//
//  iPadMainViewV.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadMainViewV: View {
    
    // Apple ID 6738694687
    
    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    var player: PlayerData
    var enemy: PlayerData
    private var gameLogicViewModel: GameLogicViewModel
    @State private var showSettingsView = false
    @State private var showNewGameOptions = false
    @State private var showContinueOptions = false

    // MARK: - Menu actions

    private func startVsComputer() {
        appState.resetData(player: player, enemy: enemy)
        player.shipsRandomArrangement()
        enemy.shipsRandomArrangement()
        appState.selectedTab = .iPadBattleView
    }

    private func continueVsComputer() {
        guard let snapshot = GameStore.load() else { return }
        snapshot.apply(to: appState, player: player, enemy: enemy)
        if appState.musicOn {
            AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
        }
        appState.selectedTab = .iPadBattleView
    }

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
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                        .ignoresSafeArea()
                    VStack(spacing: 0) {
                        Text("Sea Battle")
                            .font(.custom("Dorsa", size: geometry.size.width * 0.22))
                            .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                            .shadow(color: .white, radius: 2)
                            .padding(.top, geometry.size.height * 0.06)

                        Spacer(minLength: geometry.size.height * 0.03)

                        Image("war_ship8")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.6)
                            .cornerRadius(geometry.size.width * 0.03)
                            .shadow(color: .white, radius: 3)
                            .overlay(
                                    RoundedRectangle(cornerRadius: geometry.size.width * 0.03)
                                        .stroke(Color(red: 75/255, green: 56/255, blue: 42/255), lineWidth: 3)
                                )

                        Spacer(minLength: geometry.size.height * 0.05)

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
                                .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                                .shadow(color: .white, radius: 5)

                            // Continue — only when a resumable game exists (vs-computer
                            // save or hot-seat session; networked games can't resume).
                            if GameStore.hasSavedGame || HotSeatStore.hasSession {
                                Button {
                                    if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                                    continueGame()
                                } label: {
                                    Text("Continue game")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                    .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: geometry.size.width * 0.5, height: geometry.size.height * 0.08))
                                    .shadow(color: .white, radius: 5)
                            }
                        }

                        Spacer(minLength: geometry.size.height * 0.04)

                        // Settings — plain text link, not a wooden button.
                        Button {
                            self.showSettingsView = true
                        } label: {
                            Text("Settings")
                                .font(.custom("Aldrich", size: 34))
                                .foregroundColor(Color(red: 248/255, green: 255/255, blue: 0/255))
                                .shadow(color: .black, radius: 1, y: 1)
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                            .padding(.bottom, geometry.size.height * 0.06)
                    } // VStack off
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .sheet(isPresented: $showSettingsView) { SettingsView()
                            .presentationDetents([.fraction(0.58)])
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
                } //ZStack off
                .ignoresSafeArea()
                HStack {
                    iPadMenuViewV(width: geometry.size.width, height: geometry.size.height)
                    Spacer()
                }
                .statusBar(hidden: true)
            }
        }
    }
    init(player: PlayerData, enemy: PlayerData, gameLogicViewModel: GameLogicViewModel) {
        self.player = player
        self.enemy = enemy
        self.gameLogicViewModel = gameLogicViewModel
        }
}


#Preview {
    iPadMainViewV(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel())
        .environment(AppState())
        .environment(PremiumManager())
}

