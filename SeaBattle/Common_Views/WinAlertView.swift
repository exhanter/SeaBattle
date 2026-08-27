//
//  WinAlertView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 05/09/2024.
//

import SwiftUI

struct WinAlertView: View {
    @Environment(AppState.self) private var appState
    let didPlayerWin: Bool
    /// Restart another vs-computer match in the same mode.
    let onPlayAgain: () -> Void
    /// Return to the main menu.
    let onMenu: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .opacity(0.4)
                VStack(spacing: geometry.size.height * 0.04) {
                    Text(didPlayerWin ? "Victory!" : "Defeat!")
                        .font(.custom("Dorsa", size: 250))
                        .foregroundStyle(didPlayerWin ? Color(red: 248/255, green: 255/255, blue: 0/255) : .black)
                        .shadow(color: .white, radius: 5)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 20)

                    // Offered once the result animation has settled, so the player
                    // can immediately rematch instead of returning to the menu.
                    if appState.isTapEnabled {
                        HStack(spacing: geometry.size.width * 0.05) {
                            Button {
                                appState.isTapEnabled = false
                                onPlayAgain()
                            } label: {
                                Text("Play again")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * (AppState.isPad ? 0.045 : 0.07), width: geometry.size.width * 0.42, height: geometry.size.height * (AppState.isPad ? 0.07 : 0.09)))
                            .shadow(color: .black, radius: 4, x: 3, y: 3)

                            Button {
                                appState.isTapEnabled = false
                                onMenu()
                            } label: {
                                Text("Menu")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .buttonStyle(WoodenButton(radius: 16, fontSize: geometry.size.width * (AppState.isPad ? 0.045 : 0.07), width: geometry.size.width * 0.42, height: geometry.size.height * (AppState.isPad ? 0.07 : 0.09)))
                            .shadow(color: .black, radius: 4, x: 3, y: 3)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation { appState.isTapEnabled = true }
                }
                if appState.soundOn {
                    AppState.playSound(sound: didPlayerWin ? "victory_sound.wav" : "defeat_sound.wav")
                }
            }
        }
    }
}

#Preview("English") {
    WinAlertView(didPlayerWin: false, onPlayAgain: {}, onMenu: {})
        .environment(AppState())
}

#Preview("Dutch") {
    WinAlertView(didPlayerWin: true, onPlayAgain: {}, onMenu: {})
        .environment(AppState())
        .environment(\.locale, Locale(identifier: "NL"))
}
