//
//  gameScoreView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 30/08/2024.
//

import SwiftUI

struct gameScoreView: View {
    let player: PlayerData
    let enemy: PlayerData
    var body: some View {
        HStack {
            VStack {
                Text("\(player.numberShipsDestroyed) / 10")
                    .font(.custom("Aldrich", size: 30))
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
            }
            Spacer()
            VStack {
                Text("\(enemy.numberShipsDestroyed) / 10")
                    .font(.custom("Aldrich", size: 30))
                    .foregroundStyle(Color(red: 102/255, green: 240/255, blue: 255/255))
            }
        }
    }
}

#Preview {
    gameScoreView(player: PlayerData(name: "Player"), enemy: PlayerData(name: "Enemy"))
}
