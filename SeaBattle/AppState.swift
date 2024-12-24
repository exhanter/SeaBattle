//
//  AppState.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 18/12/2024.
//

import AVFoundation
import SwiftUI

class AppState: ObservableObject {
    
    enum DifficultyLevel: CaseIterable {
        case easy, medium, hard
    }
    enum SelectedTabs: CaseIterable {
        case menu, playerView, enemyView, about, iPadBattleFieldView
    }
    static var deviceHasWideNotch: Bool { return UIScreen.main.bounds.width == 375.0 || UIScreen.main.bounds.width == 320.0 ? true : false }
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
        if sound == "Glass_Break-stephan_schutze-958181291.wav" || sound == "blast_missed.wav" {
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
    
    func resetData(player: PlayerData, enemy: PlayerData) {
        player.cells = []
        enemy.cells = []
        self.enemysTurn = false
        enemy.showFinishGameAlert = false
        player.showFinishGameAlert = false
        player.fireStrokeArray = []
        enemy.fireStrokeArray = []
        var boolArray = [Bool]()
        for row in 1...10 {
            var arrayOfrows = [Cell]()
            for column in 1...10 {
                arrayOfrows.append(Cell(column: column, row: row))
                boolArray.append(false)
            }
            player.cells.append(arrayOfrows)
            enemy.cells.append(arrayOfrows)
            player.fireStrokeArray.append(boolArray)
            enemy.fireStrokeArray.append(boolArray)
        }
        self.gameIsActive = false
        self.selectedTab = .menu
    }
    @Published var showFinishGameAlert = false
    @Published var tabsBlocked = false
    
    var difficultyLevel: DifficultyLevel {
        switch self.difficulty {
        case 2:
            return .easy
        case 1:
            return .medium
        case 0:
            return .hard
        default:
            return .hard
        }
    }
    @Published var difficulty: Int = UserDefaults.standard.integer(forKey: "difficulty")
    @Published var enemysTurn = false
    @Published var gameIsActive = false
    @Published var soundOn: Bool
    @Published var musicOn: Bool
    @Published var selectedTab: SelectedTabs = .menu
    @Published var potentialCellsForFinishingDamagedShip: [(Int, Int)]?
    
    init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "notFirstLaunch") {
            defaults.set(true, forKey: "musicOn")
            defaults.set(true, forKey: "soundOn")
            defaults.set(true, forKey: "notFirstLaunch")
        }
        self.soundOn = UserDefaults.standard.bool(forKey: "soundOn")
        self.musicOn = UserDefaults.standard.bool(forKey: "musicOn")
    }
}
