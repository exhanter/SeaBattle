
//
//  ShipReplacementView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/09/2024.
//

import SwiftUI

struct ShipReplacementView: View {
    @ObservedObject private var replacementViewModel: ShipReplacementViewViewModel
    let leftTopPointOfGameField: CGPoint
    let cellSize: CGFloat
    @ObservedObject var player: PlayerData
    var body: some View {
        ZStack {
            ForEach(player.ships, id: \.id) { ship in
                ShipView(player: player, ship: ship, cellSize: cellSize, leftTopPointOfGameField: leftTopPointOfGameField)
                    .opacity(player.shipIsDragging[ship.number] ? 0.4 : 1)
                    .position(player.shipPositions[ship.number])
                    .gesture(
                        LongPressGesture()
                            .onEnded { _ in
                                player.ships[ship.number].orientation = player.ships[ship.number].orientation == .vertical ? .horizontal : .vertical
                                player.shipIsDragging[ship.number] = true
                                AppState.shipIsPlaced[ship.number] = false
                            }
                    )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    player.shipIsDragging[ship.number] = true
                                    player.shipPositions[ship.number] = replacementViewModel.dragGestureToShipCenterPoint(index: ship.number, cellSize: cellSize, leftTopPointOfGameField: leftTopPointOfGameField, dragGestureLocation: value.location)
                                }
                                .onEnded { _ in
                                    replacementViewModel.handleOnEndedDrag(index: ship.number, cellSize: cellSize, leftTopPointOfGameField: leftTopPointOfGameField, startCoordinates: ship.coordinates)
//                                    if AppState.shipIsPlaced[ship.number] == true {
//                                        appState.shipIsDragging[ship.number] = false
//                                    }
                                }
                        )

            }
            .ignoresSafeArea()
        }
    }
    init(leftTopPointOfGameField: CGPoint, cellSize: CGFloat, player: PlayerData) {
        self.replacementViewModel = ShipReplacementViewViewModel(player: player)
        self.leftTopPointOfGameField = leftTopPointOfGameField
        self.cellSize = cellSize
        self.player = player
    }
}

#Preview {
    ShipReplacementView(leftTopPointOfGameField: CGPoint(x: 20.5, y: 270.3), cellSize: 35, player: PlayerData(name: "Player"))
}

