//
//  YourTurnButtonView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 11/02/2025.
//

import SwiftUI

struct YourTurnButtonView: View {
    @EnvironmentObject var appState: AppState
    @State private var isBouncing = false
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Button {
            self.isBouncing = false
            if !appState.gameIsActive {
                if appState.musicOn {
                    AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                }
                appState.gameIsActive = true
                appState.manualShipArrangement = false
                appState.selectedTab = .enemyView
            } else if appState.gameIsActive {
                appState.selectedTab = .enemyView
            }
            if appState.soundOn {
                AppState.playSound(sound: "click_sound.wav")
            }
        } label: {
            Text(appState.gameIsActive ? "Your turn!" : "Start")
        }
        .accessibility(identifier: "startOrYourTurnButton")
        .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: width * 0.8, height: height * 0.1))
        .disabled(appState.enemysTurn)
        .disabled(appState.tabsBlocked)
        .shadow(color: appState.enemysTurn || appState.tabsBlocked ? .clear : .white, radius: 1, y: 1)
        .opacity(appState.enemysTurn || appState.tabsBlocked ? 0.5 : 1)
        .padding(.bottom, height * 0.15)
        .onChange(of: appState.enemysTurn) { newValue in
            if newValue == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if appState.selectedTab == .playerView {
                        withAnimation(.spring(duration: 0.3, bounce: 0.9, blendDuration: 0).repeatCount(1, autoreverses: false)) {
                            self.isBouncing = true
                        }
                    }
                }
            }
        }
        .scaleEffect(self.isBouncing ? 1.05 : 1)
    }
}

#Preview {
    YourTurnButtonView(width: 300, height: 800)
}
