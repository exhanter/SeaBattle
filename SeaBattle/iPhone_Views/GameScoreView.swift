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

    private let playerColor = Color(red: 248/255, green: 255/255, blue: 0/255)
    private let enemyColor = Color(red: 102/255, green: 240/255, blue: 255/255)

    var body: some View {
        HStack {
            // Each side: the big count plus a fleet tally where the SUNK ships
            // are crossed out — so it reads clearly as "ships sunk", not remaining.
            scoreSide(sunk: numberOfPlayersShipsDestroyed, color: playerColor)
            Spacer()
            scoreSide(sunk: numberOfEnemyShipsDestroyed, color: enemyColor)
        }
    }

    private func scoreSide(sunk: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(sunk) / 10")
                .font(AppState.isSmallPhone ? .custom("Dorsa", size: 42) : .custom("Aldrich", size: 24))
                .foregroundStyle(color)
            FleetTally(sunk: sunk, color: color, markSize: 12)
        }
    }
}

#Preview {
    GameScoreView(numberOfPlayersShipsDestroyed: 3, numberOfEnemyShipsDestroyed: 7)
        .padding()
        .background(.black)
}
