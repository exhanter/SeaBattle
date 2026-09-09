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
    /// When true (iPhone), the title + buttons are pushed to the bottom of the
    /// screen — clear of the board, over the background where the "Your turn"
    /// button normally sits. When false (iPad), they stay vertically centred.
    var alignBottom: Bool = false
    /// The gap to keep below the buttons when `alignBottom` is set (e.g. so they
    /// sit at the "Your turn" level, above the wooden tab bar).
    var bottomInset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            // Base the button metrics on the shorter screen side on iPad so they
            // look identical in portrait and landscape (otherwise landscape's
            // small height made them too short for the text).
            let shortSide = min(geometry.size.width, geometry.size.height)
            let buttonWidth = AppState.isPad ? shortSide * 0.42 : geometry.size.width * 0.42
            let buttonHeight = AppState.isPad ? shortSide * 0.10 : geometry.size.height * 0.09
            let buttonFont = AppState.isPad ? shortSide * 0.045 : geometry.size.width * 0.07
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .opacity(0.4)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(didPlayerWin ? "Victory!" : "Defeat!")
                        .font(.custom("Dorsa", size: 250))
                        .foregroundStyle(didPlayerWin ? Color(red: 248/255, green: 255/255, blue: 0/255) : .black)
                        .shadow(color: .white, radius: 5)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: geometry.size.height * 0.04)

                    // Always laid out (space reserved) so the title doesn't jump
                    // up when the buttons appear; only faded in once the result
                    // animation has settled, letting the player immediately rematch.
                    HStack(spacing: geometry.size.width * 0.05) {
                        Button {
                            appState.isTapEnabled = false
                            onPlayAgain()
                        } label: {
                            Text("Play again")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .buttonStyle(WoodenButton(radius: 16, fontSize: buttonFont, width: buttonWidth, height: buttonHeight))
                        .shadow(color: .black, radius: 4, x: 3, y: 3)

                        Button {
                            appState.isTapEnabled = false
                            onMenu()
                        } label: {
                            Text("Menu")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .buttonStyle(WoodenButton(radius: 16, fontSize: buttonFont, width: buttonWidth, height: buttonHeight))
                        .shadow(color: .black, radius: 4, x: 3, y: 3)
                    }
                    .opacity(appState.isTapEnabled ? 1 : 0)
                    .allowsHitTesting(appState.isTapEnabled)
                    .animation(.easeInOut, value: appState.isTapEnabled)

                    // Bottom region: a fixed gap pins the content low on iPhone;
                    // a flexible spacer keeps it centred on iPad.
                    if alignBottom {
                        Spacer().frame(height: bottomInset)
                    } else {
                        Spacer(minLength: 0)
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
    let state = AppState()
    state.isTapEnabled = true
    return WinAlertView(didPlayerWin: false, onPlayAgain: {}, onMenu: {})
        .environment(state)
}

#Preview("Dutch") {
    WinAlertView(didPlayerWin: true, onPlayAgain: {}, onMenu: {})
        .environment(AppState())
        .environment(\.locale, Locale(identifier: "NL"))
}
