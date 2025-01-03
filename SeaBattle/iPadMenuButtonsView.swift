//
//  iPadMenuButtonsView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/01/2025.
//

import SwiftUI

struct iPadMenuButtonsView: View {
    
    //@ObservedObject var appState: AppState
    @State private var manualShipArrangement = false
    
    let width: CGFloat
    let height: CGFloat
    let relativeFontSize: CGFloat
    
    var body: some View {
        //ZStack {
            Image("wood")
                .resizable()
                .frame(width: width, height: height)
                .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight, .bottomRight]))
                .shadow(color: .white, radius: width * 0.06)
//            VStack(alignment: .leading) {
//                Text("Ships:")
//                    .font(.custom("Dorsa", size: relativeFontSize * 1.2))
//                    .foregroundStyle(.white)
//                    .padding(.bottom, 5)
//                
//                Button {
//                    if appState.soundOn {
//                        AppState.playSound(sound: "click_sound.wav")
//                    }
//                    manualShipArrangement.toggle()
//                    appState.tabsBlocked.toggle()
//                }
//                label: {
//                    if manualShipArrangement {
//                        Text("Save")
//                            .font(.custom("Dorsa", size: relativeFontSize))
//                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
//                            .fixedSize(horizontal: true, vertical: true)
//                            .shadow(color: .white, radius: 5)
//                    } else {
//                        Text("Change")
//                            .font(.custom("Dorsa", size: relativeFontSize))
//                            .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
//                            .fixedSize(horizontal: true, vertical: true)
//                    }
//                }
//                .padding(.bottom, 2)
//                Button {
//                    if appState.soundOn {
//                        AppState.playSound(sound: "click_sound.wav")
//                    }
//                    player.clearShips()
//                    player.shipsRandomArrangement()
//                }
//                label: {
//                    Text("Shuffle")
//                        .font(.custom("Dorsa", size: relativeFontSize))
//                        .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
//                        .fixedSize(horizontal: true, vertical: true)
//                        //.shadow(color: .white, radius: 5)
//                }
//            }
        //}
    }
    init(width: CGFloat, height: CGFloat) {
        self.width = width * 0.11
        self.height = height * 0.2
        self.relativeFontSize = width * 0.06
    }
}

#Preview {
    iPadMenuButtonsView(width: 500, height: 400)
}
