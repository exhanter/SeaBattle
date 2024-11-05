//
//  BattleFieldView-ViewModel.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 19/07/2024.
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
                player.defineSafeAreaNearShip(ship: ship)
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
            switch player.difficultyLevel {
                
            case .easy:
                
                if row != 1 && player.cells[row - 2][column - 1].cellStatus == .showShipOnFire { // check upper cell if it was damaged
                    for step in 1...2 {
                        if row - 2 - step >= 0 && player.cells[row - 2 - step][column - 1].cellStatus != .showShipOnFire {
                            if player.cells[row - 2 - step][column - 1].cellStatus == .missed {
                                arrayOfCells.append((row + 1, column))
                                return arrayOfCells
                            } else if player.cells[row - 2 - step][column - 1].cellStatus != .showShipOnFire || player.cells[row - 2 - step][column - 1].cellStatus != .destroyed {
                                arrayOfCells.append((row - 1 - step, column))
                                if row != 10 {
                                    if player.cells[row][column - 1].cellStatus != .showShipOnFire || player.cells[row][column - 1].cellStatus != .destroyed {
                                        arrayOfCells.append((row + 1, column))
                                    }
                                }
                            }
                            return arrayOfCells
                        } else if row - 2 - step < 0 {
                            arrayOfCells.append((row + 1, column))
                            return arrayOfCells
                        }
                    }
                }
                
                if row != 10 && player.cells[row][column - 1].cellStatus == .showShipOnFire { // check lower cell if it was damaged
                    for step in 1...2 {
                        if row + step < 10 && player.cells[row + step][column - 1].cellStatus != .showShipOnFire {
                            if player.cells[row + step][column - 1].cellStatus != .showShipOnFire || player.cells[row + step][column - 1].cellStatus != .destroyed {
                                arrayOfCells.append((row - 1, column))
                                return arrayOfCells
                            } else if player.cells[row + step][column - 1].cellStatus == .unknown {
                                arrayOfCells.append((row + 1 + step, column))
                                if row != 1 {
                                    if player.cells[row - 2][column - 1].cellStatus != .showShipOnFire || player.cells[row - 2][column - 1].cellStatus != .destroyed {
                                        arrayOfCells.append((row - 1, column))
                                    }
                                }
                            }
                            return arrayOfCells
                        } else if row + step >= 10 {
                            arrayOfCells.append((row - 1, column))
                            return arrayOfCells
                        }
                    }
                }
                
                if column != 1 && player.cells[row - 1][column - 2].cellStatus == .showShipOnFire { // check left cell if it was damaged
                    for step in 1...2 {
                        if column - 2 - step >= 0 && player.cells[row - 1][column - 2 - step].cellStatus != .showShipOnFire {
                            if player.cells[row - 1][column - 2 - step].cellStatus == .missed {
                                arrayOfCells.append((row, column + 1))
                                return arrayOfCells
                            } else if player.cells[row - 1][column - 2 - step].cellStatus != .showShipOnFire || player.cells[row - 1][column - 2 - step].cellStatus != .destroyed  {
                                arrayOfCells.append((row, column - 1 - step))
                                if column != 10 {
                                    if player.cells[row - 1][column].cellStatus != .showShipOnFire || player.cells[row - 1][column].cellStatus != .destroyed {
                                        arrayOfCells.append((row, column + 1))
                                    }
                                }
                            }
                            return arrayOfCells
                        } else if column - 2 - step < 0 {
                            arrayOfCells.append((row, column + 1))
                            return arrayOfCells
                        }
                    }
                }
                if column != 10 && player.cells[row - 1][column].cellStatus == .showShipOnFire { // check right cell if it was damaged
                    for step in 1...2 {
                        if column + step < 10 && player.cells[row - 1][column + step].cellStatus != .showShipOnFire {
                            if player.cells[row - 1][column + step].cellStatus == .missed {
                                arrayOfCells.append((row, column - 1))
                                return arrayOfCells
                            } else if player.cells[row - 1][column + step].cellStatus != .showShipOnFire || player.cells[row - 1][column + step].cellStatus != .destroyed {
                                arrayOfCells.append((row, column + 1 + step))
                                if column != 1 {
                                    if player.cells[row - 1][column - 2].cellStatus != .showShipOnFire || player.cells[row - 1][column - 2].cellStatus != .destroyed {
                                        arrayOfCells.append((row, column - 1))
                                    }
                                }
                            }
                            return arrayOfCells
                        } else if column + step >= 10 {
                            arrayOfCells.append((row, column - 1))
                            return arrayOfCells
                        }
                    }
                }
                if row != 1 && player.cells[row - 2][column - 1].isAvailable {    arrayOfCells.append((row - 1, column)) }
                if row != 10 && player.cells[row][column - 1].isAvailable {       arrayOfCells.append((row + 1, column)) }
                if column != 1 && player.cells[row - 1][column - 2].isAvailable { arrayOfCells.append((row, column - 1)) }
                if column != 10 && player.cells[row - 1][column].isAvailable {    arrayOfCells.append((row, column + 1)) }
                print("Returing array of cells: \(arrayOfCells)")
                return arrayOfCells
                
            case .medium, .hard:
                
                if row != 1 && player.cells[row - 2][column - 1].cellStatus == .showShipOnFire { // check upper cell if it was damaged
                    for step in 1...2 {
                        if row - 2 - step >= 0 && player.cells[row - 2 - step][column - 1].cellStatus != .showShipOnFire {
                            if player.cells[row - 2 - step][column - 1].cellStatus == .missed || !player.cells[row - 2 - step][column - 1].isAvailable {
                                arrayOfCells.append((row + 1, column))
                                return arrayOfCells
                            } else if player.cells[row - 2 - step][column - 1].isAvailable {
                                arrayOfCells.append((row - 1 - step, column))
                                if row != 10 && player.cells[row][column - 1].isAvailable {
                                    arrayOfCells.append((row + 1, column))
                                }
                            }
                            return arrayOfCells
                        } else if row - 2 - step < 0 {
                            arrayOfCells.append((row + 1, column))
                            return arrayOfCells
                        }
                    }
                }
                
                if row != 10 && player.cells[row][column - 1].cellStatus == .showShipOnFire { // check lower cell if it was damaged
                    for step in 1...2 {
                        if row + step < 10 && player.cells[row + step][column - 1].cellStatus != .showShipOnFire {
                            if player.cells[row + step][column - 1].cellStatus == .missed || !player.cells[row + step][column - 1].isAvailable {
                                arrayOfCells.append((row - 1, column))
                                return arrayOfCells
                            } else if player.cells[row + step][column - 1].isAvailable {
                                arrayOfCells.append((row + 1 + step, column))
                                if row != 1 && player.cells[row - 2][column - 1].isAvailable {
                                    arrayOfCells.append((row - 1, column))
                                }
                            }
                            return arrayOfCells
                        } else if row + step >= 10 {
                            arrayOfCells.append((row - 1, column))
                            return arrayOfCells
                        }
                    }
                }
                
                if column != 1 && player.cells[row - 1][column - 2].cellStatus == .showShipOnFire { // check left cell if it was damaged
                    for step in 1...2 {
                        if column - 2 - step >= 0 && player.cells[row - 1][column - 2 - step].cellStatus != .showShipOnFire {
                            if player.cells[row - 1][column - 2 - step].cellStatus == .missed || !player.cells[row - 1][column - 2 - step].isAvailable {
                                arrayOfCells.append((row, column + 1))
                                return arrayOfCells
                            } else if player.cells[row - 1][column - 2 - step].isAvailable {
                                arrayOfCells.append((row, column - 1 - step))
                                if column != 10 && player.cells[row - 1][column].isAvailable {
                                    arrayOfCells.append((row, column + 1))
                                }
                            }
                            return arrayOfCells
                        } else if column - 2 - step < 0 {
                            arrayOfCells.append((row, column + 1))
                            return arrayOfCells
                        }
                    }
                }
                if column != 10 && player.cells[row - 1][column].cellStatus == .showShipOnFire { // check right cell if it was damaged
                    for step in 1...2 {
                        if column + step < 10 && player.cells[row - 1][column + step].cellStatus != .showShipOnFire {
                            if player.cells[row - 1][column + step].cellStatus == .missed || !player.cells[row - 1][column + step].isAvailable {
                                arrayOfCells.append((row, column - 1))
                                return arrayOfCells
                            } else if player.cells[row - 1][column + step].isAvailable {
                                arrayOfCells.append((row, column + 1 + step))
                                if column != 1 && player.cells[row - 1][column - 2].isAvailable {
                                    arrayOfCells.append((row, column - 1))
                                }
                            }
                            return arrayOfCells
                        } else if column + step >= 10 {
                            arrayOfCells.append((row, column - 1))
                            return arrayOfCells
                        }
                    }
                }
                
                if row != 1 && player.cells[row - 2][column - 1].isAvailable {    arrayOfCells.append((row - 1, column)) }
                if row != 10 && player.cells[row][column - 1].isAvailable {       arrayOfCells.append((row + 1, column)) }
                if column != 1 && player.cells[row - 1][column - 2].isAvailable { arrayOfCells.append((row, column - 1)) }
                if column != 10 && player.cells[row - 1][column].isAvailable {    arrayOfCells.append((row, column + 1)) }
                return arrayOfCells
                }
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
                        print("Array from findAvailable...: \(arrayOfPriorityCells)")
                        repeat {
                            coordinates = arrayOfPriorityCells.randomElement()!
                            row = coordinates.0
                            column = coordinates.1
                            print("Cell from findAvailable...: \(row) \(column) is available \(player.cells[row - 1][column - 1].isAvailable)")
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
                print("Circle is \(row) \(column) while meet conditions")
            } while !meetConditionsToDefineCellForFire(coordinates: coordinates)
            return coordinates
        }
        
        func meetConditionsToDefineCellForFire(coordinates: (Int, Int)) -> Bool {
            let row = coordinates.0
            let column = coordinates.1
            switch player.difficultyLevel {
            case .easy:
                print("Cell available at \(row) \(column) is \(player.cells[row - 1][column - 1].isAvailable)")
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
