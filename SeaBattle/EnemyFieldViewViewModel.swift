//
//  BattleFieldView-ViewModel.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 19/07/2024.
//

import Foundation

extension EnemyFieldView {
    @Observable
    class EnemyFieldViewViewModel {
        
        //  При повторном нажатии на подбитый корабль звук подбитого корабля
        // во время хода игрока нельхя выйти в меню и выключить игру, можно зайти на поле игрока, но оттуда все будет заблокировано -  только после настройки кораблей
        var player: PlayerData
        var enemy: PlayerData
        var sound = ""
        var fireStroke = false
        
        init(enemy: PlayerData, player: PlayerData) {
            self.enemy = enemy
            self.player = player
        }
        
        func checkShipOnFire(row: Int, column: Int, target: PlayerData) {
            if target.cells[row - 1][column - 1].isAvailable {
                for ship in target.ships {
                    if ship.coordinates.contains(where: { $0 == (row, column) }) {
                        target.cells[row - 1][column - 1].cellStatus = target.name == "Player" ? .showShipOnFire : .onFire
                        if !checkShipIsTotallyDestroyed(ship: ship, target: target) && target.name == "Player" {
                            sound = "blast_onfire2.wav"
                            player.potentialCellsForFinishingDamagedShip = definePriorityTargetCells(row: row, column: column)
                        }
                        target.cells[row - 1][column - 1].isAvailable = false
                        if player.soundIsOn {
                            PlayerData.playSound(sound: sound)
                        }
                        sound = ""
                        return
                    }
                }
                sound = "blast_missed.wav"
                target.cells[row - 1][column - 1].cellStatus = .missed
                target.cells[row - 1][column - 1].isAvailable = false
                if player.soundIsOn {
                    PlayerData.playSound(sound: sound)
                }
                sound = ""
            }
            player.enemysTurn = target.name == "Enemy" ? true : false
            return
        }
        
        func checkShipIsTotallyDestroyed(ship: Ship, target: PlayerData) -> Bool {
            for coordinate in ship.coordinates {
                if target.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus != .onFire && target.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus != .showShipOnFire {
                    return false
                }
            }
            for coordinate in ship.coordinates {
                target.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus = .destroyed
            }
            
            if let index = target.ships.firstIndex(where: { $0.id == ship.id }) {
                target.ships[index].isDestroyed = true
            }
            if target.name == "Player" {
                player.potentialCellsForFinishingDamagedShip = nil
                sound = "Glass_Break-stephan_schutze-958181291.wav"
                if player.difficultyLevel != .easy { player.defineSafeAreaNearShip(ship: ship) }
            }
            if target.numberShipsDestroyed == 10 {
                PlayerData.musicPlayer?.stop()
                player.gameIsActive = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    target.showFinishGameAlert = true
                }
            }
            return true
        }
        
        func definePriorityTargetCells(row: Int, column: Int) -> [(Int, Int)]? {
            var arrayOfCells = [(Int, Int)]()
            let upperCell = row == 1 ? Cell(column: 0, row: 0) : player.cells[row - 2][column - 1]
            let bottomCell = row == 10 ? Cell(column: 0, row: 0) : player.cells[row][column - 1]
            let leftCell = column == 1 ? Cell(column: 0, row: 0) : player.cells[row - 1][column - 2]
            let rightCell = column == 10 ? Cell(column: 0, row: 0) : player.cells[row - 1][column]
            
            if row != 1 && upperCell.cellStatus == .showShipOnFire { // check upper cell if it was damaged
                for step in 1...2 {
                    let upperUpperRow = row - 2 - step
                    let upperUpperCell = upperUpperRow < 0 ? player.cells[0][0] : player.cells[upperUpperRow][column - 1]
                    if upperUpperRow >= 0 && upperUpperCell.cellStatus != .showShipOnFire {
                        if upperUpperCell.cellStatus == .missed || !upperUpperCell.isAvailable {
                            arrayOfCells.append((row + 1, column)) // add bottom cell to array
                            return arrayOfCells
                        } else if upperUpperCell.isAvailable {
                            arrayOfCells.append((upperUpperRow + 1, column)) // add upper upper cell to array
                            if row != 10 && bottomCell.isAvailable {
                                arrayOfCells.append((row + 1, column)) // add bottom cell to array
                            }
                        }
                        return arrayOfCells
                    } else if upperUpperRow < 0 {
                        arrayOfCells.append((row + 1, column)) // add bottom cell to array
                        return arrayOfCells
                    }
                }
            }
            
            if row != 10 && bottomCell.cellStatus == .showShipOnFire { // check lower cell if it was damaged
                for step in 1...2 {
                    let bottomBottomRow = row + step
                    let bottomBottomCell = bottomBottomRow < 10 ? player.cells[bottomBottomRow][column - 1] : player.cells[0][0]
                    if bottomBottomRow < 10 && bottomBottomCell.cellStatus != .showShipOnFire {
                        if bottomBottomCell.cellStatus == .missed || !bottomBottomCell.isAvailable {
                            arrayOfCells.append((row - 1, column)) // add upper cell to array
                            return arrayOfCells
                        } else if bottomBottomCell.isAvailable {
                            arrayOfCells.append((bottomBottomRow + 1, column)) // add bottom bottom cell to array
                            if row != 1 && upperCell.isAvailable {
                                arrayOfCells.append((row - 1, column)) // add upper cell to array
                            }
                        }
                        return arrayOfCells
                    } else if bottomBottomRow >= 10 {
                        arrayOfCells.append((row - 1, column)) // add upper cell to array
                        return arrayOfCells
                    }
                }
            }
            
            if column != 1 && leftCell.cellStatus == .showShipOnFire { // check left cell if it was damaged
                for step in 1...2 {
                    let leftLeftColumn = column - 2 - step
                    let leftLeftCell = leftLeftColumn < 0 ? player.cells[0][0] : player.cells[row - 1][leftLeftColumn]
                    if leftLeftColumn >= 0 && leftLeftCell.cellStatus != .showShipOnFire {
                        if leftLeftCell.cellStatus == .missed || !leftLeftCell.isAvailable {
                            arrayOfCells.append((row, column + 1)) // add right cell to array
                            return arrayOfCells
                        } else if leftLeftCell.isAvailable {
                            arrayOfCells.append((row, leftLeftColumn + 1)) // add left left cell to array
                            if column != 10 && rightCell.isAvailable {
                                arrayOfCells.append((row, column + 1)) // add right cell to array
                            }
                        }
                        return arrayOfCells
                    } else if leftLeftColumn < 0 {
                        arrayOfCells.append((row, column + 1)) // add right cell to array
                        return arrayOfCells
                    }
                }
            }
            if column != 10 && rightCell.cellStatus == .showShipOnFire { // check right cell if it was damaged
                for step in 1...2 {
                    let rightRightColumn = column + step
                    let rightRightCell = rightRightColumn < 10 ? player.cells[row - 1][rightRightColumn] : player.cells[0][0]
                    if rightRightColumn < 10 && rightRightCell.cellStatus != .showShipOnFire {
                        if rightRightCell.cellStatus == .missed || !rightRightCell.isAvailable {
                            arrayOfCells.append((row, column - 1)) // add left cell to array
                            return arrayOfCells
                        } else if rightRightCell.isAvailable {
                            arrayOfCells.append((row, rightRightColumn + 1)) // add right right cell to array
                            if column != 1 && leftCell.isAvailable {
                                arrayOfCells.append((row, column - 1)) // add left cell to array
                            }
                        }
                        return arrayOfCells
                    } else if rightRightColumn >= 10 {
                        arrayOfCells.append((row, column - 1)) // add left cell to array
                        return arrayOfCells
                    }
                }
            }
            
            if row != 1 && upperCell.isAvailable     { arrayOfCells.append((row - 1, column)) }
            if row != 10 && bottomCell.isAvailable   { arrayOfCells.append((row + 1, column)) }
            if column != 1 && leftCell.isAvailable   { arrayOfCells.append((row, column - 1)) }
            if column != 10 && rightCell.isAvailable { arrayOfCells.append((row, column + 1)) }
            return arrayOfCells
        }
        
        func computerTurn() {
            var coordinatesForFire = (0, 0)
            var row = 0
            var column = 0

            func performShot() {
                coordinatesForFire = findAvailableCellsForFire()
                row = coordinatesForFire.0
                column = coordinatesForFire.1
                
                player.fireStrokeArray[row - 1][column - 1] = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.player.fireStrokeArray[row - 1][column - 1] = false
                }

                checkShipOnFire(row: row, column: column, target: player)

                if player.cells[row - 1][column - 1].cellStatus != .missed && player.gameIsActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        performShot()
                        
                    }
                }
            }

            performShot()
        }
        
        func findAvailableCellsForFire() -> (Int, Int) {
            var row: Int = 0
            var column: Int = 0
            var coordinates: (Int, Int) = (0, 0)
            repeat {
                // If some ship was damaged, we need to find it's undamaged cells first
                if let arrayOfPriorityCells = player.potentialCellsForFinishingDamagedShip {
                    if arrayOfPriorityCells.count > 0 {
                        repeat {
                            coordinates = arrayOfPriorityCells.randomElement()!
                            row = coordinates.0
                            column = coordinates.1
                        } while !player.cells[row - 1][column - 1].isAvailable
                    } else {
                        row = Int.random(in: 1...10)
                        column = Int.random(in: 1...10)
                        coordinates = (row, column)
                    }
                }   else {
                    row = Int.random(in: 1...10)
                    column = Int.random(in: 1...10)
                    coordinates = (row, column)
                }
            } while !meetConditionsToDefineCellForFire(coordinates: coordinates)
            return coordinates
        }
        
        func meetConditionsToDefineCellForFire(coordinates: (Int, Int)) -> Bool {
            let row = coordinates.0
            let column = coordinates.1
            switch player.difficultyLevel {
            case .easy:
                return player.cells[row - 1][column - 1].isAvailable ? true : false
            case .medium:
                return player.cells[row - 1][column - 1].isAvailable ? true : false
                // more logic
            case .hard:
                return player.cells[row - 1][column - 1].isAvailable ? true : false
                // more complex logic here to come
                // define minimum decks of remaining ships
                // define cells nearby to fit the smallest enemy ship
                // logic to define the most relevant cell to fire (cross?)
                
            }
        }
        
        func chooseSound(row: Int, column: Int) {
            switch enemy.cells[row][column].cellStatus {
            case .missed:
                PlayerData.playSound(sound: "blast_missed.wav")
            case .onFire:
                PlayerData.playSound(sound: "blast_onfire2.wav")
            case .destroyed:
                PlayerData.playSound(sound: "Glass_Break-stephan_schutze-958181291.wav")
            default:
                PlayerData.playSound(sound: "click_sound.wav")
            }
        }
    }
}
