//
//  ShipView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/09/2024.
//

import SwiftUI

struct ShipView: View {
    @ObservedObject var player: PlayerData
    var ship: Ship
    let cellSize: CGFloat
    let leftTopPointOfGameField: CGPoint
    var body: some View {
        switch ship.numberOfDecks {
            case 1:
            CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
            case 2:
                if ship.orientation == .horizontal {
                    HStack(spacing: 0) {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                    }
                } else if ship.orientation == .vertical {
                    VStack(spacing: 0) {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                    }
                }
            case 3:
                if ship.orientation == .horizontal {
                    HStack(spacing: 0) {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                    }
                } else if ship.orientation == .vertical {
                    VStack(spacing: 0) {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                    }
                }
            case 4:
                if ship.orientation == .horizontal {
                    HStack(spacing: 0) {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                    }
                } else if ship.orientation == .vertical {
                    VStack(spacing: 0) {
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                        CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
                    }
                }
            default:
                CellView(fireStrokeIsOn: player.fireStrokeArray[0][0], cellStatus: .showShipHalo, cellWidth: cellSize)
            }
    }
}

#Preview {
    let ship4v = Ship(number: 1, orientation: .vertical, numberOfDecks: 4, coordinates: [(1,1), (2,1), (3,1), (4,1)])
    ShipView(player: PlayerData(name: "Player"), ship: ship4v, cellSize: 35, leftTopPointOfGameField: CGPoint(x: 0, y: 0))
}
