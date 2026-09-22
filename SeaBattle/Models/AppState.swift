//
//  AppState.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 18/12/2024.
//

import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
class AppState {

    enum DifficultyLevel: String, Codable, CaseIterable {
        case easy, medium, hard, expert

        /// Points awarded for a win at this level — and the cost of one hint at
        /// this level (hint cost == win reward). Higher levels are worth more.
        var pointsValue: Int {
            switch self {
            case .easy: return 1
            case .medium: return 3
            case .hard: return 6
            case .expert: return 10
            }
        }
    }
    enum SelectedTabs: CaseIterable {
        case menu, playerView, enemyView, about, iPadBattleView
    }

    var difficulty: Int = UserDefaults.standard.integer(forKey: "difficulty")
    var enemysTurn = false
    var gameIsActive = false
    /// True from the moment a fleet is fully sunk until the next reset. Unlike
    /// `gameIsActive` (which also is false *before* a match starts), this marks a
    /// match that has *ended*, so the "Start" button stays hidden during the
    /// brief window before the win/defeat alert appears.
    var gameIsOver = false
    var soundOn: Bool
    var musicOn: Bool
    var selectedTab: SelectedTabs = .menu
    /// Enemy cells revealed to the player by a paid hint (Phase 6). Transient —
    /// cleared on reset.
    var revealedHintCells: [(Int, Int)] = []
    var manualShipArrangement: Bool = false
    var tabsBlocked = false
    var isTapEnabled = false
    var language: String
    /// Optional beginner protection: reveal the empty ring around a sunk ship so
    /// you can't waste shots there. Default off (firing there stays allowed).
    var autoRevealAroundSunk: Bool
    /// Transient presentation flags (set from the menu, presented at the root so
    /// the covers survive layout changes — notably on iPad).
    var showHotSeat = false
    var showNearby = false
    var showOnline = false
    var showPaywall = false
    /// What the user was trying to do when a premium paywall opened, so the
    /// action can be completed automatically once they subscribe.
    enum PremiumIntent { case expert, hotSeat, nearby, online }
    var pendingPremiumIntent: PremiumIntent?
    
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    /// True on the narrow iPhones (SE / mini, 375 and 320 pt wide), which need a
    /// smaller type scale. TODO (R2): the redesign sizes everything from the
    /// container, so this goes away with the old views.
    static var isSmallPhone: Bool {
        let width = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
            .first ?? 393
        return width <= 375
    }

    // MARK: - Audio

    // Sound and music live in `AudioService` (R0.2). These forwarders keep the
    // existing call sites working; new code should call `AudioService.shared`.

    static func playMusic(sound: String) {
        AudioService.shared.startMusic()
    }

    static func stopMusic() {
        AudioService.shared.stopMusic()
    }

    static func playSound(sound: String) {
        AudioService.shared.play(named: sound)
    }
    
    func resetData(player: PlayerData, enemy: PlayerData) {
        player.cells = []
        enemy.cells = []
        self.enemysTurn = false
        self.revealedHintCells = []
        enemy.showFinishGameAlert = false
        player.showFinishGameAlert = false
        player.fireStrokeArray = []
        enemy.fireStrokeArray = []
        // A 10 x 10 grid per side. The previous version reused one growing
        // `boolArray` across rows, so `fireStrokeArray` came out ragged
        // (10, 20, ... 100 entries per row) — 550 values instead of 100.
        for row in 1...10 {
            var arrayOfrows = [Cell]()
            for column in 1...10 {
                arrayOfrows.append(Cell(column: column, row: row))
            }
            player.cells.append(arrayOfrows)
            enemy.cells.append(arrayOfrows)
            player.fireStrokeArray.append([Bool](repeating: false, count: 10))
            enemy.fireStrokeArray.append([Bool](repeating: false, count: 10))
        }
        self.gameIsActive = false
        self.gameIsOver = false
        self.selectedTab = .menu
        // Starting a new game or stopping the current one discards the save.
        GameStore.clear()
    }
    
    var difficultyLevel: DifficultyLevel {
        switch self.difficulty {
        case 2:
            return .easy
        case 1:
            return .medium
        case 0:
            return .hard
        case 3:
            return .expert
        default:
            return .hard
        }
    }
    
    init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "notFirstLaunch") {
            defaults.set(true, forKey: "musicOn")
            defaults.set(true, forKey: "soundOn")
            defaults.set(true, forKey: "notFirstLaunch")
        }
        self.soundOn = UserDefaults.standard.bool(forKey: "soundOn")
        self.musicOn = UserDefaults.standard.bool(forKey: "musicOn")
        self.language = UserDefaults.standard.string(forKey: "Language") ?? Locale.current.identifier
        self.autoRevealAroundSunk = UserDefaults.standard.bool(forKey: "autoRevealAroundSunk")
        // Touching the service configures the audio session (playback category,
        // so the game is heard with the mute switch on).
        _ = AudioService.shared
    }
}
