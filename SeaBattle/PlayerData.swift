//
//  Data.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import SwiftUI
import AVFoundation

@Observable class PlayerData {
    
    enum DifficultyLevel: CaseIterable {
        case easy, medium, hard
    }
    enum SelectedTabs: CaseIterable {
        case menu, playerView, enemyView, about
    }
    static var musicPlayer: AVAudioPlayer?
    static var soundPlayer: AVAudioPlayer?
    static var shipIsPlaced: [Bool] = Array(repeating: true, count: 10)
    
    static func playMusic(sound: String) {
        guard let soundURL = Bundle.main.url(forResource: sound, withExtension: "") else { return }
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: soundURL)
            self.musicPlayer?.numberOfLoops = -1
            musicPlayer?.volume = 0.5
            musicPlayer?.play()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    static func playSound(sound: String) {
        var level: Float = 1.0
        if sound == "Glass_Break-stephan_schutze-958181291.wav" {
            level = 2.0
        }
        guard let soundURL = Bundle.main.url(forResource: sound, withExtension: "") else { return }
        do {
            soundPlayer = try AVAudioPlayer(contentsOf: soundURL)
            soundPlayer?.play()
            soundPlayer?.volume = level
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    static func resetData(player: PlayerData, enemy: PlayerData) {
        player.cells = []
        enemy.cells = []
        player.enemysTurn = false
        enemy.showFinishGameAlert = false
        player.showFinishGameAlert = false
        for row in 1...10 {
            var arrayOfrows = [Cell]()
            for column in 1...10 {
                arrayOfrows.append(Cell(column: column, row: row))
            }
            player.cells.append(arrayOfrows)
            enemy.cells.append(arrayOfrows)
        }
        player.gameIsActive = false
        player.selectedTab = .menu
    }
    
    let name: String
    var cells = [[Cell]]()
    var ships = [Ship]()
    var showFinishGameAlert = false
    var shipsDestroyed: [Ship] {
        return ships.filter{ $0.isDestroyed }
    }
    var numberShipsDestroyed: Int {
        return shipsDestroyed.count
    }
    
    // common properties like static
    var tabsBlocked = false
    
    var difficultyLevel: DifficultyLevel {
        switch self.difficulty {
        case 0:
            return .easy
        case 1:
            return .medium
        case 2:
            return .hard
        default:
            return .easy
        }
    }
    var difficulty: Int = UserDefaults.standard.integer(forKey: "difficulty")
    
    var enemysTurn = false
    var gameIsActive = false
    var soundIsOn = true
    var musicIsOn = true
    var selectedTab: SelectedTabs = .menu
    var potentialCellsForFinishingDamagedShip: [(Int, Int)]?
    var shipIsDragging: [Bool] = Array(repeating: false, count: 10)
    var shipPositions: [CGPoint] = Array(repeating: .zero, count: 10)
    var fireStrokeArray = [[Bool]]()
    
    func shipsRandomArrangement() {
        self.shipPositions = Array(repeating: .zero, count: 10)
        let ship4 = randomDataForShip(number: 0, numberOfDecks: 4)
        defineSafeAreaNearShip(ship: ship4)
        let ship31 = randomDataForShip(number: 1, numberOfDecks: 3)
        defineSafeAreaNearShip(ship: ship31)
        let ship32 = randomDataForShip(number: 2, numberOfDecks: 3)
        defineSafeAreaNearShip(ship: ship32)
        let ship21 = randomDataForShip(number: 3, numberOfDecks: 2)
        defineSafeAreaNearShip(ship: ship21)
        let ship22 = randomDataForShip(number: 4, numberOfDecks: 2)
        defineSafeAreaNearShip(ship: ship22)
        let ship23 = randomDataForShip(number: 5, numberOfDecks: 2)
        defineSafeAreaNearShip(ship: ship23)
        let ship11 = randomDataForShip(number: 6, numberOfDecks: 1)
        defineSafeAreaNearShip(ship: ship11)
        let ship12 = randomDataForShip(number: 7, numberOfDecks: 1)
        defineSafeAreaNearShip(ship: ship12)
        let ship13 = randomDataForShip(number: 8, numberOfDecks: 1)
        defineSafeAreaNearShip(ship: ship13)
        let ship14 = randomDataForShip(number: 9, numberOfDecks: 1)
        defineSafeAreaNearShip(ship: ship14)
        makeCellsAvailableAgain()
        self.ships = [ship4, ship31, ship32, ship21, ship22, ship23, ship11, ship12, ship13, ship14]
    }
    
    func defineSafeAreaNearShip(ship: Ship) {
        let lastIndex = ship.numberOfDecks - 1
        var rowStartOffset = 0
        var rowFinishOffset = 0
        var columnStartOffset = 0
        var columnFinishOffset = 0
        
        if ship.coordinates[0].0 == 1 {
            rowStartOffset = 0 // start from the edge instead of -1
            rowFinishOffset = 1 //finish at the position +1
        } else if ship.coordinates[lastIndex].0 == 10 {
            rowStartOffset = -1
            rowFinishOffset = 0
        } else {
            rowStartOffset = -1
            rowFinishOffset = 1
        }
        if ship.coordinates[0].1 == 1 {
            columnStartOffset = 0 // start from the edge instead of -1
            columnFinishOffset = 1 //finish at the position +1
        } else if ship.coordinates[lastIndex].1 == 10 {
            columnStartOffset = -1
            columnFinishOffset = 0
        } else {
            columnStartOffset = -1
            columnFinishOffset = 1
        }
        for row in ship.coordinates[0].0 + rowStartOffset...ship.coordinates[ship.numberOfDecks-1].0 + rowFinishOffset {
            for column in ship.coordinates[0].1 + columnStartOffset...ship.coordinates[ship.numberOfDecks-1].1 + columnFinishOffset {
                self.cells[row - 1][column - 1].isAvailable = false
            }
        }
    }
    
    func makeCellsAvailableAgain() { // only for player cells
        for x in 0 ..< 10 {
            for y in 0 ..< 10 {
                self.cells[x][y].isAvailable = true
            }
        }
    }
    
    func randomDataForShip(number: Int, numberOfDecks: Int) -> Ship {
        var coordinates: [(Int, Int)] = []
        var orientation: Ship.Orientation = .vertical
        var row = 0
        var column = 0
        repeat {
            coordinates = []
            orientation = [.vertical, .horizontal].randomElement()!
            if orientation == .horizontal {
                row = Int.random(in: 0...9)
                column = Int.random(in: 0...10 - numberOfDecks)
            } else if orientation == .vertical {
                row = Int.random(in: 0...10 - numberOfDecks)
                column = Int.random(in: 0...9)
            }
            if orientation == .horizontal {
                for i in column + 1...column + numberOfDecks {
                    coordinates.append((row + 1, i))
                }
            }
            if orientation == .vertical {
                for i in row + 1...row + numberOfDecks {
                    coordinates.append((i, column + 1))
                }
            }
        } while !cellIsAvailableForPlacingShip(coordinates: coordinates)
        
        if self.name == "Player" {
            for coordinate in coordinates {
                self.cells[coordinate.0 - 1][coordinate.1 - 1].cellStatus = .showShip
            }
        }

        return Ship(player: self, number: number, orientation: orientation, numberOfDecks: numberOfDecks, coordinates: coordinates)
    }
    
    func cellIsAvailableForPlacingShip(coordinates: [(Int, Int)]) -> Bool {
        for coordinate in coordinates {
            let row = coordinate.0 - 1
            let column = coordinate.1 - 1
            
            if !self.cells.indices.contains(row) || !self.cells[row].indices.contains(column) {
                return false
            }
            
            guard self.cells[row][column].isAvailable else {
                return false
            }
        }
        return true
    }
    
    func defineShipPositionsAsCGPoint(leftTopPointOfGameField: CGPoint, cellSize: CGFloat) {
        self.shipPositions = []
        for ship in self.ships {
            if let lastCoordinate = ship.coordinates.last {
                var correctionX: CGFloat = .zero
                var correctionY: CGFloat = .zero
                if ship.orientation == .vertical {
                    correctionX = -cellSize / 2
                    correctionY = -(CGFloat(ship.numberOfDecks) * cellSize) / 2
                } else if ship.orientation == .horizontal {
                    correctionX = -(CGFloat(ship.numberOfDecks) * cellSize) / 2
                    correctionY = -cellSize / 2
                }
                let x = CGFloat(lastCoordinate.1) * cellSize + leftTopPointOfGameField.x + correctionX
                let y = CGFloat(lastCoordinate.0) * cellSize + leftTopPointOfGameField.y + correctionY
                self.shipPositions.append(CGPoint(x: x, y: y))
            }
        }
    }
    
    init(name: String) {
        self.name = name
        var boolArray = [Bool()]
        for row in 1...10 {
            var arrayOfRows = [Cell]()
            for column in 1...10 {
                arrayOfRows.append(Cell(column: column, row: row))
                boolArray.append(false)
            }
            self.cells.append(arrayOfRows)
            self.fireStrokeArray.append(boolArray)
        }
    }
}
