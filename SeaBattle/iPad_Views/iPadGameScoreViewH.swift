//
//  iPadGameScoreViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 10/02/2025.
//

import SwiftUI

struct iPadGameScoreViewH: View {
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
//        VStack {
            HStack(alignment: .top, spacing: 0) {
                Spacer()
                Text("Player \(player.numberShipsDestroyed) / 10") // 8 char max
                    .font(.custom("Aldrich", size: width * 0.04))
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                    .shadow(color: Color(red: 0.11, green: 0.77, blue: 0.56), radius: 1)
                Spacer()
                Spacer()
                Text("Enemy \(enemy.numberShipsDestroyed) / 10")
                    .font(.custom("Aldrich", size: width * 0.04))
                    .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))
                    .shadow(color: Color(red: 0.11, green: 0.77, blue: 0.56), radius: 1)
                Spacer()
            }
            .padding(.top, height * 0.11)//0.0132
            .padding(.horizontal, width * 0.04)
//        }
    }
}

#Preview {
    iPadGameScoreViewH(player: PlayerData(name: "testPlayer"), enemy: PlayerData(name: "testEnemy"), width: 300, height: 800)
}
