//
//  iPadStartButton.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2025.
//

import SwiftUI

struct iPadStartButton: View {
    
    @EnvironmentObject var appState: AppState
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Button("Start") {
            if !appState.gameIsActive {
                if appState.musicOn {
                    AppState.playMusic(sound: "Battles_on_the_High_Seas.mp3")
                }
                appState.gameIsActive = true
                appState.manualShipArrangement = false
            }
            if appState.soundOn {
                AppState.playSound(sound: "click_sound.wav")
            }
        }
        .buttonStyle(WoodenButton(radius: 20, fontSize: 40, width: width * 0.3, height: height * 0.07))
        .shadow(color: .black, radius: width * 0.015, x: 5, y: 5)
        .disabled(appState.tabsBlocked)
        .opacity(appState.tabsBlocked ? 0.5 : 1)
    }
    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

#Preview {
    iPadStartButton(width: 600, height: 1200)
}
