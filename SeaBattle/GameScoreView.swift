//
//  gameScoreView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 30/08/2024.
//

import SwiftUI

struct GameScoreView: View {
    let numberOfPlayersShipsDestroyed: Int
    let numberOfEnemyShipsDestroyed: Int
    var body: some View {
        HStack {
            VStack {
                Text("\(numberOfPlayersShipsDestroyed) / 10")
                    .font(AppState.deviceHasWideNotch ? .custom("Dorsa", size: 42) : .custom("Aldrich", size: 30))
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
            }
            Spacer()
            VStack {
                Text("\(numberOfEnemyShipsDestroyed) / 10")
                    .font(AppState.deviceHasWideNotch ? .custom("Dorsa", size: 42) : .custom("Aldrich", size: 30))
                    .foregroundStyle(Color(red: 102/255, green: 240/255, blue: 255/255))
            }
        }
    }
}

#Preview {
    GameScoreView(numberOfPlayersShipsDestroyed: 3, numberOfEnemyShipsDestroyed: 3)
}
