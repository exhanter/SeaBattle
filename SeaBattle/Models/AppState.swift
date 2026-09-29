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

        /// How much water this level lets its own fleet give away, in cells, or
        /// `nil` to arrange at random and not care.
        ///
        /// Sinking a ship reveals that everything touching it is water, so a
        /// fleet packed against the edges and into each other's gaps hands the
        /// player far fewer free cells. This is by far the strongest lever in
        /// the game: every targeting improvement in the ladder put together is
        /// worth about three shots a match, and this one is worth twenty.
        ///
        /// **It is therefore a difficulty dial, not something to maximise.**
        /// Measured win rates against an opponent shooting as well as the
        /// expert does, with the player opening (`ExpertPlacementTests`):
        ///
        ///     62 cells (as random)  60%
        ///     58 cells              65%   <- expert
        ///     54 cells              80%
        ///     50 cells              81%
        ///     42 cells              96%
        ///     34 cells (the floor) 100%
        ///
        /// A live player is weaker than that opponent, so the real rate is
        /// higher than the table. 58 leaves the expert clearly the hardest
        /// thing in the app while still losing often enough that the 10 points
        /// for beating it, and the hints priced against it, mean something.
        /// Hiding as well as possible wins literally every match, and a level
        /// nobody can beat pays out nothing.
        ///
        /// Only the expert hides, and that is now the main thing separating it
        /// from `.hard`, whose shooting is only a shot or two behind.
        var fleetExposureTarget: Int? {
            switch self {
            case .easy, .medium: return nil
            case .hard: return 58
            case .expert: return 54
            }
        }

        /// The number this level is stored as in `UserDefaults`, kept from the
        /// first versions of the game. The order is **not** by difficulty —
        /// changing it would silently reset the setting for everybody who
        /// already has the app, so it stays as it is.
        var storedValue: Int {
            switch self {
            case .hard: return 0
            case .medium: return 1
            case .easy: return 2
            case .expert: return 3
            }
        }

        /// Only the expert is behind Pro (design log, "Уровни одиночной игры").
        var isPremium: Bool { self == .expert }

        /// What a player without Pro gets offered instead of the expert. Not a
        /// silent downgrade: the level screen shows up and says so (spec 4.3).
        static let freeFallback: DifficultyLevel = .hard
    }
    enum SelectedTabs: CaseIterable {
        case menu, playerView, enemyView, about, iPadBattleView
    }

    /// Legacy storage of the level: see `DifficultyLevel.storedValue`. Read and
    /// written through `difficultyLevel`, which is the typed way in.
    var difficulty: Int
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
    /// Whether picking the computer's level is a step before a single-player
    /// match (spec 4.3 and the setting in 4.11). **On by default**; off starts
    /// the match straight away at the remembered level.
    ///
    /// Persisted here rather than by the settings screen: the flag is read by
    /// the menu and written by two screens, and the old convention of "the view
    /// writes `UserDefaults` in `onChange`" loses the value the first time
    /// somebody adds a third writer.
    var askLevelBeforeMatch: Bool {
        didSet {
            UserDefaults.standard.set(askLevelBeforeMatch, forKey: Self.askLevelKey)
        }
    }
    private static let askLevelKey = "askLevelBeforeMatch"
    /// «Спрашивать подтверждение выстрела» (spec 4.5, 4.11): the first tap on
    /// the opponent's board aims, the second one fires. **Off by default**, so
    /// a quick game stays one tap per shot. Persisted here for the same reason
    /// as `askLevelBeforeMatch`.
    var confirmShot: Bool {
        didSet {
            UserDefaults.standard.set(confirmShot, forKey: Self.confirmShotKey)
        }
    }
    private static let confirmShotKey = "confirmShot"
    /// «Своё поле в горизонтальной ориентации» (spec 4.11, iPad only): which
    /// side of the landscape table holds your own board. **Left by default** —
    /// the opponent's board sits under the right hand. The feed, the hint and
    /// the score blocks move with the boards; role colours never change.
    var ownBoardOnRight: Bool {
        didSet {
            UserDefaults.standard.set(ownBoardOnRight, forKey: Self.ownBoardOnRightKey)
        }
    }
    private static let ownBoardOnRightKey = "ownBoardOnRight"
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
    
    /// The level the computer plays at. Writing it **persists** — the level is
    /// remembered between matches (spec 4.3), and having every screen remember
    /// to write `UserDefaults` itself is how one of them forgets.
    var difficultyLevel: DifficultyLevel {
        get {
            switch self.difficulty {
            case 2: return .easy
            case 1: return .medium
            case 0: return .hard
            case 3: return .expert
            default: return .hard
            }
        }
        set {
            difficulty = newValue.storedValue
            UserDefaults.standard.set(difficulty, forKey: "difficulty")
        }
    }
    
    init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "notFirstLaunch") {
            defaults.set(true, forKey: "musicOn")
            defaults.set(true, forKey: "soundOn")
            defaults.set(true, forKey: "notFirstLaunch")
            // Spec 4.3: the level selected on a first launch is medium. Without
            // this the stored 0 would mean "hard", because that is what an
            // absent integer reads as.
            defaults.set(DifficultyLevel.medium.storedValue, forKey: "difficulty")
        }
        self.difficulty = defaults.integer(forKey: "difficulty")
        // An absent flag has to read as `true` (asking is the default), and
        // `bool(forKey:)` would read it as `false` for everybody who already
        // has the app installed.
        self.askLevelBeforeMatch = defaults.object(forKey: Self.askLevelKey) as? Bool ?? true
        self.confirmShot = defaults.bool(forKey: Self.confirmShotKey)
        self.ownBoardOnRight = defaults.bool(forKey: Self.ownBoardOnRightKey)
        self.soundOn = UserDefaults.standard.bool(forKey: "soundOn")
        self.musicOn = UserDefaults.standard.bool(forKey: "musicOn")
        self.language = UserDefaults.standard.string(forKey: "Language") ?? Locale.current.identifier
        self.autoRevealAroundSunk = UserDefaults.standard.bool(forKey: "autoRevealAroundSunk")
        // Touching the service configures the audio session (playback category,
        // so the game is heard with the mute switch on).
        _ = AudioService.shared
    }
}
