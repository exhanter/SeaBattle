//
//  iPadShipArrangementMenuViewV.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 11/02/2025.
//

import SwiftUI

struct iPadShipArrangementMenuViewV: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    iPadMenuButtonsViewV(width: width, height: height)
                        VStack(alignment: .leading) {
                            Text("Ships:")
                                .font(.custom("Dorsa", size: width * 0.07))
                                .foregroundStyle(.white)
                                .padding(.bottom, 5)
            
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                appState.manualShipArrangement.toggle()
                                appState.tabsBlocked.toggle()
                            }
                            label: {
                                Text("Change")
                                    .font(.custom("Dorsa", size: width * 0.06))
                                    .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                    .fixedSize(horizontal: true, vertical: true)
                                    .shadow(color: appState.manualShipArrangement ? .white : .clear, radius: 5)
                            }
                            .padding(.bottom, 2)
                            .disabled(appState.gameIsActive)
                            .disabled(player.shipIsDragging.contains(true))
                            .opacity(appState.gameIsActive ? 0.5 : 1)
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                player.clearShips()
                                player.shipsRandomArrangement()
                            }
                            label: {
                                Text("Shuffle")
                                    .font(.custom("Dorsa", size: width * 0.06))
                                    .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                            .disabled(appState.tabsBlocked)
                            .disabled(appState.gameIsActive)
                            .disabled(player.shipIsDragging.contains(true))
                            .opacity(appState.gameIsActive ? 0.5 : 1)
                            .opacity(appState.tabsBlocked ? 0.5 : 1)
                        }
                        .padding(.leading, width * 0.0132)
                }
                Spacer()
            }
            Spacer()
        }
    }
}

#Preview {
    iPadShipArrangementMenuViewV(player: PlayerData(name: "testPlayer"), width: 300, height: 800)
}
