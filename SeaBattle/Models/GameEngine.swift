//
//  GameEngine.swift
//  SeaBattle
//
//  Phase 0: the transport-agnostic core of the game. It owns all board
//  mutation — applying a shot, detecting sunk ships, computing the priority
//  cells for finishing a damaged ship and detecting the end of the match.
//  It has no knowledge of WHO is playing: the same engine is driven by the
//  computer (ComputerOpponent), a second on-device human (hot-seat) or a
//  remote player (network). `GameLogicViewModel` is a thin facade over it.
//

import Foundation

@MainActor
final class GameEngine {

    private(set) var appState: AppState!
    private(set) var player: PlayerData!
    private(set) var enemy: PlayerData!
    private var sound = ""

    /// Injects the shared game objects once the owning view is on screen.
    func configure(appState: AppState, player: PlayerData, enemy: PlayerData) {
        self.appState = appState
        self.player = player
        self.enemy = enemy
    }

    /// Checks the cell status and marks it as "missed" or "onFire". If it is
    /// "onFire" the method calls additional methods.
    func checkShipOnFire(row: Int, column: Int, target: PlayerData) {
        if target.cells[row - 1][column - 1].isAvailable {
            for ship in target.ships {
                if ship.coordinates.contains(where: { $0 == (row, column) }) {
                    target.cells[row - 1][column - 1].cellStatus = target.name == "Player" ? .showShipOnFire : .onFire
                    if !checkShipIsTotallyDestroyed(ship: ship, target: target) && target.name == "Player" {
                        sound = "blast_onfire2.wav"
                        appState.potentialCellsForFinishingDamagedShip = definePriorityTargetCells(row: row, column: column)
                    }
                    target.cells[row - 1][column - 1].isAvailable = false
                    if appState.soundOn {
                        AppState.playSound(sound: sound)
                    }
                    sound = ""
                    return
                }
            }
            sound = "blast_missed.wav"
            target.cells[row - 1][column - 1].cellStatus = .missed
            target.cells[row - 1][column - 1].isAvailable = false
            if appState.soundOn {
                AppState.playSound(sound: sound)
            }
            sound = ""
        }
        appState.enemysTurn = target.name == "Enemy" ? true : false
        return
    }

    /// Checks if the ship is destroyed after the last shot and marks all the
    /// cells as "destroyed". RETURNS true or false.
    @discardableResult
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
            appState.potentialCellsForFinishingDamagedShip = nil
            sound = "Glass_Break-stephan_schutze-958181291.wav"
            if appState.difficultyLevel != .easy { player.defineSafeAreaNearShip(ship: ship) }
        } else if appState.autoRevealAroundSunk {
            // Beginner protection on the enemy board: reveal the empty ring.
            target.markSafeAreaAsMissed(ship: ship)
        }
        if target.numberShipsDestroyed == 10 {
            appState.gameIsActive = false
            AppState.musicPlayer?.stop()
            // The match is over — drop the saved game.
            GameStore.clear()
            // Record the result: the side whose whole fleet is sunk is the loser.
            if target.name == "Enemy" {
                ProgressStore.shared.recordWin(at: appState.difficultyLevel)
            } else {
                ProgressStore.shared.recordLoss()
            }
            Task {
                try? await Task.sleep(for: .seconds(1))
                target.showFinishGameAlert = true
            }
        }
        return true
    }

    /// Accepts one coordinate and defines all possible cells for fire.
    /// RETURNS: array of possible cells.
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
}
