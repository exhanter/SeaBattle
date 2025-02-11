//
//  iPadShipArrangementMenuViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 11/02/2025.
//

import SwiftUI

struct iPadShipArrangementMenuViewH: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                ZStack(alignment: .leading) {
                    iPadMenuButtonsViewH(width: width, height: height)
                    HStack(alignment: .bottom) {
                            Text("Ships:")
                                .font(.custom("Dorsa", size: height * 0.06))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: true, vertical: true)
            
                            Button {
                                if appState.soundOn {
                                    AppState.playSound(sound: "click_sound.wav")
                                }
                                appState.manualShipArrangement.toggle()
                                appState.tabsBlocked.toggle()
                            }
                            label: {
                                Text("Change")
                                    .font(.custom("Dorsa", size: width * 0.04))
                                    .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                    .fixedSize(horizontal: true, vertical: true)
                                    .shadow(color: appState.manualShipArrangement ? .white : .clear, radius: 5)
                            }
                            .padding(.horizontal, width * 0.003)
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
                                    .font(.custom("Dorsa", size: width * 0.04))
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
        }
    }
}

#Preview {
    iPadShipArrangementMenuViewH(player: PlayerData(name: "testPlayer"), width: 300, height: 800)
}
