//
//  ShipArrangementMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 11/02/2025.
//

import SwiftUI

struct UpperLabelAndButtonView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if width / height < 0.56 {
            Text("Player")
                .font(Font.custom("Aldrich", size: 48))
                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                .shadow(color: .black, radius: 1, y: 2)
                .padding(.bottom, height * 0.02)
        }
        Button {
            if appState.soundOn {
                AppState.playSound(sound: "click_sound.wav")
            }
            appState.manualShipArrangement.toggle()
            appState.tabsBlocked.toggle()
        } label: {
            Text(appState.manualShipArrangement ? "Save" : "Change")
        }
            .accessibility(identifier: "changeOrSaveButton")
            .buttonStyle(WoodenButton(radius: 11, fontSize: 20, width: width * 0.5, height: height * 0.05))
            .disabled(appState.gameIsActive)
            .disabled(player.shipIsDragging.contains(true))
            .shadow(color: appState.gameIsActive || player.shipIsDragging.contains(true) ? .clear : .white, radius: 1, y: 0.5)
            .opacity(appState.gameIsActive || player.shipIsDragging.contains(true) ? 0.5 : 1)
    }
}

#Preview {
    UpperLabelAndButtonView(player: PlayerData(name: "testPlayer"), width: 300, height: 800)
}
