//
//  iPadGameScoreView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 08/02/2025.
//

import SwiftUI

struct iPadGameScoreViewV: View {
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    var width: CGFloat
    
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
            Spacer()
        }
    }
}

#Preview {
    iPadGameScoreViewV(player: PlayerData(name: "testPLayer"), enemy: PlayerData(name: "testEnemy"), width: 200)
}
