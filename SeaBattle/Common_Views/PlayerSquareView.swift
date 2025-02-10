//
//  PlayerSquareView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2025.
//

import SwiftUI

struct PlayerSquareView: View {
    @ObservedObject var player: PlayerData
    @Binding var leftTopPointOfGameField: CGPoint
    @EnvironmentObject var appState: AppState
    
    let width: CGFloat
    
    var body: some View {
        ForEach(1...10, id:\.self) { row in
            HStack(spacing: 0) {
                ForEach(1...10, id: \.self) { column in
                    if appState.manualShipArrangement {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[row - 1][column - 1], cellStatus: .unknown, cellWidth: width)
                            .background(GeometryReader { geometryLocal in
                                Color.clear
                                    .onAppear {
                                        self.leftTopPointOfGameField = geometryLocal.frame(in: .global).origin
                                        player.defineShipPositionsAsCGPoint(leftTopPointOfGameField: leftTopPointOfGameField, cellSize: width)
                                    }
                            })
                    } else {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[row - 1][column - 1], cellStatus: player.cells[row - 1][column - 1].cellStatus, cellWidth: width)
                    }
                }
            }
        }
        //.ignoresSafeArea()
    }
    init(player: PlayerData, leftTopPointOfGameField: Binding<CGPoint>, width: CGFloat) {
        self.player = player
        self._leftTopPointOfGameField = leftTopPointOfGameField
        self.width = width
    }
}

#Preview {
    PlayerSquareView(player: PlayerData(name: "testPlayer"), leftTopPointOfGameField: .constant(.zero), width: 600)
}
