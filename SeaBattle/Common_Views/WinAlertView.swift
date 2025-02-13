//
//  WinAlertView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 05/09/2024.
//

import SwiftUI

struct WinAlertView: View {
    @EnvironmentObject var appState: AppState
    let didPlayerWin: Bool
    
    var body: some View {
        
        Color.black
            .ignoresSafeArea()
            .opacity(0.4)
        VStack(alignment: .center) {
            Text(didPlayerWin ? "Victory!" : "Defeat!")
                .font(.custom("Dorsa", size: 250))
        }
        .foregroundStyle(didPlayerWin ? Color(red: 248/255, green: 255/255, blue: 0/255) : .black)
        .shadow(color: .white, radius: 5)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .padding(.horizontal, 20)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    appState.isTapEnabled = true
                }
                if appState.soundOn {
                    AppState.playSound(sound: didPlayerWin ? "victory_sound.wav" : "defeat_sound.wav")
                }
            }
    }
}

#Preview("English") {
    WinAlertView(didPlayerWin: false)
}

#Preview("Dutch") {
    WinAlertView(didPlayerWin: true)
        .environment(\.locale, Locale(identifier: "NL"))
}
