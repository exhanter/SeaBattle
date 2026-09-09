//
//  iPadGameScoreView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 08/02/2025.
//

import SwiftUI

struct iPadGameScoreViewV: View {
    var player: PlayerData
    var enemy: PlayerData
    let width: CGFloat
    
    var body: some View {
        VStack {
            Spacer()
            Text("Player") // 8 char max
                .font(.custom("Aldrich", size: width * 0.04))//width * 0.04
                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                .shadow(color: Color(red: 0.11, green: 0.77, blue: 0.56), radius: 1)
                .padding(.bottom, 5)
            Text("\(player.numberShipsDestroyed) / 10")
                .font(.custom("Aldrich", size: width * 0.04))
                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                .shadow(color: Color(red: 0.11, green: 0.77, blue: 0.56), radius: 1)
            // Crossed-out marks = ships SUNK (compact 5×2 to stay off the board).
            FleetTally(sunk: player.numberShipsDestroyed,
                       color: Color(red: 248/255, green: 255/255, blue: 0/255),
                       markSize: width * 0.022, perRow: 5)
                .padding(.top, 4)
            Spacer()
            Spacer()
            Text("Enemy")
                .font(.custom("Aldrich", size: width * 0.04))
                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                .shadow(color: Color(red: 0.04, green: 0.10, blue: 0.25), radius: 5)
                .padding(.bottom, 5)
            Text("\(enemy.numberShipsDestroyed) / 10")
                .font(.custom("Aldrich", size: width * 0.04))
                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                .shadow(color: Color(red: 0.04, green: 0.10, blue: 0.25), radius: 5)
            FleetTally(sunk: enemy.numberShipsDestroyed,
                       color: Color(red: 248/255, green: 255/255, blue: 0/255),
                       markSize: width * 0.022, perRow: 5)
                .padding(.top, 4)
            Spacer()
        }
    }
}

#Preview {
    iPadGameScoreViewV(player: PlayerData(name: "testPLayer"), enemy: PlayerData(name: "testEnemy"), width: 200)
}
