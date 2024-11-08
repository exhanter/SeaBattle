//
//  ShipReplacementViewViewModel.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 13/09/2024.
//

import SwiftUI

extension ShipReplacementView {
    @Observable
    class ShipReplacementViewViewModel {
        var player: PlayerData
        
        init(player: PlayerData) {
            self.player = player
        }
        
        func dragGestureToShipCenterPoint(index: Int, cellSize: CGFloat, leftTopPointOfGameField: CGPoint, dragGestureLocation: CGPoint) -> CGPoint {
            let cellSize = cellSize
            var newX = ceil((dragGestureLocation.x - leftTopPointOfGameField.x) / cellSize) * cellSize + leftTopPointOfGameField.x - cellSize / 2
            var newY = ceil((dragGestureLocation.y - leftTopPointOfGameField.y) / cellSize) * cellSize + leftTopPointOfGameField.y - cellSize / 2
            if player.ships[index].numberOfDecks % 2 == 0 {
                var correctionX: CGFloat = .zero
                var correctionY: CGFloat = .zero
                if player.ships[index].orientation == .vertical {
                    correctionY = cellSize / 2
                    newY += correctionY
                } else if player.ships[index].orientation == .horizontal {
                    correctionX = cellSize / 2
                    newX += correctionX
                }
            }
            let halfShipX = player.ships[index].orientation == .horizontal ? CGFloat(player.ships[index].numberOfDecks) / 2 * cellSize : cellSize / 2
            let maxX = leftTopPointOfGameField.x + cellSize * 10 - halfShipX
            let minX = leftTopPointOfGameField.x + halfShipX
            if newX > maxX {
                newX = maxX
            } else if newX < minX {
                newX = minX
            }
            let halfShipY = player.ships[index].orientation == .vertical ? CGFloat(player.ships[index].numberOfDecks) / 2 * cellSize : cellSize / 2
            let maxY = leftTopPointOfGameField.y + cellSize * 10 - halfShipY
            let minY = leftTopPointOfGameField.y + halfShipY
            if newY > maxY {
                newY = maxY
            } else if newY < minY {
                newY = minY
            }
            return CGPoint(x: newX, y: newY)
        }
        
        func handleOnEndedDrag(index: Int, cellSize: CGFloat, leftTopPointOfGameField: CGPoint, startCoordinates: [(Int, Int)]) {
            for ship in player.ships {
                if ship.id != player.ships[index].id {
                    player.defineSafeAreaNearShip(ship: ship)
                }
            }
            let newCoordinates = self.convertCenterCGPointToShipCoordinates(index: index, cellSize: cellSize, leftTopPointOfGameField: leftTopPointOfGameField)
            if !self.newShipCrossesOthers(index: index, newCoordinates: newCoordinates) {
                    player.ships[index].coordinates = newCoordinates
                PlayerData.shipIsPlaced[index] = true
                } else {
                    PlayerData.shipIsPlaced[index] = false
                    player.ships[index].coordinates = newCoordinates // temp to check how it goes
//                    guard !PlayerData.shipIsPlaced[index] else {
//                        player.ships[index].coordinates = startCoordinates
//                        PlayerData.shipPositions[index] = self.convertLastCellToCenterCGPoint(index: index, cellSize: cellSize, leftTopPointOfGameField: leftTopPointOfGameField)
//                        player.makeCellsAvailableAgain()
//                        return
//                    }
                }
            for coordinate in startCoordinates {
                player.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus = .unknown
                for ship in player.ships {
                    if ship.coordinates.contains(where: { $0 == coordinate }) {
                        player.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus = .showShip
                    }
                }

            }
            for coordinate in player.ships[index].coordinates {
                player.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus = .showShip
            }
            if PlayerData.shipIsPlaced[index] == true {
                player.shipIsDragging[index] = false
            }
            player.makeCellsAvailableAgain()
        }
        
        func newShipCrossesOthers(index: Int, newCoordinates: [(Int, Int)]) -> Bool {
            for newCoordinate in newCoordinates {
                for ship in player.ships {
                    if ship.coordinates.contains(where: { $0 == newCoordinate }) && ship.id != player.ships[index].id {
                        return true
                    }
                    if !player.cells[newCoordinate.0 - 1][newCoordinate.1 - 1].isAvailable && !player.ships[index].coordinates.contains(where: { $0 == newCoordinate }) {
                        return true
                    }
                }
            }
            return false
        }
        
        func convertLastCellToCenterCGPoint(index: Int, cellSize: CGFloat, leftTopPointOfGameField: CGPoint) -> CGPoint {
            if let lastCoordinate = player.ships[index].coordinates.last {
                var correctionX: CGFloat = .zero
                var correctionY: CGFloat = .zero
                if player.ships[index].orientation == .vertical {
                    correctionX = -cellSize / 2
                    correctionY = -(CGFloat(player.ships[index].numberOfDecks) * cellSize) / 2
                } else if player.ships[index].orientation == .horizontal {
                    correctionX = -(CGFloat(player.ships[index].numberOfDecks) * cellSize) / 2
                    correctionY = -cellSize / 2
                }
                let x = CGFloat(lastCoordinate.1) * cellSize + leftTopPointOfGameField.x + correctionX
                let y = CGFloat(lastCoordinate.0) * cellSize + leftTopPointOfGameField.y + correctionY
                return CGPoint(x: x, y: y)
            }
            return .zero
        }
        
        func convertCenterCGPointToShipCoordinates(index: Int, cellSize: CGFloat, leftTopPointOfGameField: CGPoint) -> [(Int, Int)] {
            
            var correctionX: CGFloat = .zero
            var correctionY: CGFloat = .zero
            var coordinates: [(Int,Int)] = []
            if player.ships[index].orientation == .vertical {
                correctionX = cellSize / 2
                correctionY = (CGFloat(player.ships[index].numberOfDecks) * cellSize) / 2
            } else if player.ships[index].orientation == .horizontal {
                correctionX = (CGFloat(player.ships[index].numberOfDecks) * cellSize) / 2
                correctionY = cellSize / 2
            }
            let column = Int(round(((player.shipPositions[index].x + correctionX - leftTopPointOfGameField.x) / cellSize)))
            let row = Int(round((player.shipPositions[index].y + correctionY - leftTopPointOfGameField.y) / cellSize))
            for i in 0 ..< player.ships[index].numberOfDecks {
                if player.ships[index].orientation == .vertical {
                    coordinates.append((row - i, column))
                } else if player.ships[index].orientation == .horizontal {
                    coordinates.append((row, column - i))
                }
            }
            coordinates.reverse()
            for coordinate in coordinates {
                if coordinate.0 < 1 || coordinate.1 < 1 || coordinate.0 > 10 || coordinate.1 > 10 {
                    return player.ships[index].coordinates
                }
            }
            return coordinates
        }
        func convertCGPointToUnitPoint(ship: Ship, point: CGPoint, screenWidth: CGFloat, screenHeight: CGFloat) -> UnitPoint {
            let cellSize = screenWidth * 0.09
            var correctionX: CGFloat = 0
            var correctionY: CGFloat = 0
            if ship.orientation == .vertical {
                correctionX = -cellSize / 2
                correctionY = -(CGFloat(ship.numberOfDecks) * cellSize) / 2
            } else if ship.orientation == .horizontal {
                correctionX = -(CGFloat(ship.numberOfDecks) * cellSize) / 2
                correctionY = -cellSize / 2
            }
            let x = (point.x + correctionX) / screenWidth
            let y = (point.y + correctionY) / screenHeight
            return UnitPoint(x: x, y: y)
        }
        func handleLongPressOnChanged(ship: Ship) {
            if ship.orientation == .vertical {
                
            } else if ship.orientation == .horizontal {
                
            }
            
        }
        func handleLongPressOnEnded(ship: Ship) {
            
        }
        
        
    }
}
