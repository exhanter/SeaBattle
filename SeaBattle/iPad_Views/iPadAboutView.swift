//
//  iPadAboutView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadAboutView: View {
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var player: PlayerData
    @ObservedObject var enemy: PlayerData
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadAboutViewV(player: player, enemy: enemy)
            } else {
                iPadAboutViewH(player: player, enemy: enemy)
            }
        }
    }
}

#Preview {
    iPadAboutView(player: PlayerData(name: "testPlayer"), enemy: PlayerData(name: "testEnemy"))
        .environmentObject(AppState(tempInstance: true))
}
