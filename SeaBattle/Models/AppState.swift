//
//  AppState.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 18/12/2024.
//

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
            case .hard: return 5
            case .expert: return 10
            }
        }

        /// The share of matches in which this level hides its own fleet
        /// (`FleetLayout.hiddenArrangement`); in the rest it arranges at random.
        /// Which matches those are is drawn afresh every time and never shown.
        ///
        /// Hiding is the strongest lever in the game against a player who does
        /// not expect it — sinking a ship reveals the water around it, and a
        /// hidden fleet gives away about 55 cells of it instead of 62 — and it
        /// works AGAINST the computer once the player does expect it: hidden
        /// ships favour the edges and each other's gaps, and a player who fires
        /// there first finds them sooner. Before 09.10 the expert hid in every
        /// match, and a player who had worked that out beat it 72% of the time
        /// on attack alone.
        ///
        /// Hiding only sometimes is what fixes that: the player cannot know
        /// whether this match is one of them. Shots the best-responding player
        /// needs to clear the fleet, by share (16 000 matches per point, so
        /// ±0.04; the player's best strategy changes along the table):
        ///
        ///     never      56.19
        ///     10%        56.81
        ///     15.5%      57.15   <- the peak
        ///     20%        57.04
        ///     30%        56.75
        ///     40%        56.43
        ///     always     53.1  (the old hill climb, readable on top)
        ///
        /// At the peak, expecting the hiding and ignoring it cost the player the
        /// same, so there is nothing left to learn: the best adjustment for it
        /// saves 0.06 shots a match. Above it, expecting it pays and the level
        /// gets easier; below it, the hiding is too rare to cost anything.
        ///
        /// Only the expert hides. `.hard` used to as well (always, to 58 cells),
        /// and that was the readable kind, so it now arranges at random.
        var hiddenFleetShare: Double {
            switch self {
            case .easy, .medium, .hard: return 0
            case .expert: return 0.16
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

        /// The reverse of `storedValue`; anything unknown reads as hard, the
        /// default level.
        init(storedValue: Int) {
            self = Self.allCases.first { $0.storedValue == storedValue } ?? .hard
        }

        /// Only the expert is behind Pro (design log, "Уровни одиночной игры").
        var isPremium: Bool { self == .expert }

        /// What a player without Pro gets offered instead of the expert. Not a
        /// silent downgrade: the level screen shows up and says so (spec 4.3).
        static let freeFallback: DifficultyLevel = .hard
    }
    enum SelectedTabs: CaseIterable {
        case menu, playerView, enemyView
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
    // R4.2: звук, музыка, язык и обводка сохраняются здесь, как
    // `askLevelBeforeMatch`: правило «экран пишет `UserDefaults` сам» теряет
    // значение у второго писателя, который забудет.
    var soundOn: Bool {
        didSet { UserDefaults.standard.set(soundOn, forKey: "soundOn") }
    }
    var musicOn: Bool {
        didSet { UserDefaults.standard.set(musicOn, forKey: "musicOn") }
    }
    /// R4.3a: вибрация на события боя. Включена по умолчанию; сама вибрация
    /// и её выключатель — в `HapticService`, флаг лишь хранит выбор.
    var hapticsOn: Bool {
        didSet {
            UserDefaults.standard.set(hapticsOn, forKey: Self.hapticsOnKey)
            HapticService.shared.isEnabled = hapticsOn
        }
    }
    private static let hapticsOnKey = "hapticsOn"
    /// R4.4: the two first-launch screens have been passed (or skipped).
    var onboardingDone: Bool {
        didSet { UserDefaults.standard.set(onboardingDone, forKey: Self.onboardingDoneKey) }
    }
    private static let onboardingDoneKey = "onboardingDone"
    /// R4.4: the device owner's name, icon and color; `nil` until given.
    var ownPlayer: OwnPlayer? {
        didSet {
            let data = ownPlayer.flatMap { try? JSONEncoder().encode($0) }
            UserDefaults.standard.set(data, forKey: Self.ownPlayerKey)
        }
    }
    private static let ownPlayerKey = "ownPlayer"
    var selectedTab: SelectedTabs = .menu
    /// Enemy cells revealed to the player by a paid hint (Phase 6). Transient —
    /// cleared on reset.
    var revealedHintCells: [(Int, Int)] = []
    var manualShipArrangement: Bool = false
    /// Interface language: `ru`, `en` or `nl` (`supportedLanguage(_:)`). Feeds
    /// `\.locale` at the root, so it changes the text and the board letters
    /// at once — mid-match too (spec 4.11).
    var language: String {
        didSet { UserDefaults.standard.set(language, forKey: Self.languageKey) }
    }
    nonisolated private static let languageKey = "Language"
    nonisolated static let supportedLanguages = ["ru", "en", "nl"]

    /// The game's language for code with no `\.locale` at hand — what
    /// `language` holds, read straight from `UserDefaults`, so models and
    /// formatters off the main actor can ask too.
    nonisolated static var gameLocale: Locale {
        Locale(identifier: supportedLanguage(UserDefaults.standard.string(forKey: languageKey)
                                             ?? Locale.preferredLanguages.first))
    }

    /// One of `supportedLanguages` for anything stored or reported by the
    /// system. Older builds stored `"EN"`, `"NL"` or the system locale
    /// identifier (`"ru_NL"`, `"en_US"`); a language the game doesn't speak
    /// reads as English.
    nonisolated static func supportedLanguage(_ identifier: String?) -> String {
        guard let identifier,
              let code = Locale(identifier: identifier).language.languageCode?.identifier.lowercased(),
              supportedLanguages.contains(code) else { return "en" }
        return code
    }
    /// Optional beginner protection: reveal the empty ring around a sunk ship so
    /// you can't waste shots there. Default off (firing there stays allowed).
    var autoRevealAroundSunk: Bool {
        didSet { UserDefaults.standard.set(autoRevealAroundSunk, forKey: "autoRevealAroundSunk") }
    }
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
    /// «Подтверждать завершение партии» (заказчик 08.10): второй вопрос у
    /// «Завершить партию» в окне выхода и «Удалить» у корзины в меню.
    /// **Вкл. по умолчанию**; выключенный — удаляет с первого нажатия.
    var confirmEndMatch: Bool {
        didSet { UserDefaults.standard.set(confirmEndMatch, forKey: Self.confirmEndMatchKey) }
    }
    private static let confirmEndMatchKey = "confirmEndMatch"
    /// «Своё поле в горизонтальной ориентации» (spec 4.11, iPad only): which
    /// side of the landscape table holds your own board. **Left by default** —
    /// the opponent's board sits under the right hand. The feed, the hint and
    /// the score blocks move with the boards; role colors never change.
    var ownBoardOnRight: Bool {
        didSet {
            UserDefaults.standard.set(ownBoardOnRight, forKey: Self.ownBoardOnRightKey)
        }
    }
    private static let ownBoardOnRightKey = "ownBoardOnRight"
    /// The full Pro paywall, presented at the root so the cover survives layout
    /// changes — notably on iPad.
    var showPaywall = false
    /// What the user was trying to do when a premium paywall opened, so the
    /// action can be completed automatically once they subscribe.
    enum PremiumIntent { case expert, hotSeat, nearby, online }
    var pendingPremiumIntent: PremiumIntent?

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
        get { DifficultyLevel(storedValue: difficulty) }
        set {
            difficulty = newValue.storedValue
            UserDefaults.standard.set(difficulty, forKey: "difficulty")
        }
    }
    
    /// Onboarding is for a new player only. `notFirstLaunch` has been written
    /// on the first launch of every build since 2024, so whoever has it but no
    /// stored onboarding flag played before R4.4 and is not greeted again.
    nonisolated static func onboardingDone(stored: Bool?, isFreshInstall: Bool) -> Bool {
        stored ?? !isFreshInstall
    }

    init() {
        let defaults = UserDefaults.standard
        let isFreshInstall = !defaults.bool(forKey: "notFirstLaunch")
        let storedOnboarding = defaults.object(forKey: Self.onboardingDoneKey) == nil
            ? nil : defaults.bool(forKey: Self.onboardingDoneKey)
        self.onboardingDone = Self.onboardingDone(stored: storedOnboarding,
                                                  isFreshInstall: isFreshInstall)
        self.ownPlayer = OwnPlayer.decode(defaults.data(forKey: Self.ownPlayerKey))
        if isFreshInstall {
            // Written now, not when onboarding ends: closed on the welcome
            // screen, the app would otherwise come back with `notFirstLaunch`
            // set and no flag — and take the newcomer for an old player.
            defaults.set(false, forKey: Self.onboardingDoneKey)
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
        // has the app installed. A present one goes through `bool(forKey:)`,
        // not `as? Bool`: a launch argument (`-askLevelBeforeMatch NO`, the UI
        // tests) arrives as the string "NO", which `as? Bool` reads as absent.
        self.askLevelBeforeMatch = Self.flag(Self.askLevelKey, absent: true, in: defaults)
        self.confirmEndMatch = Self.flag(Self.confirmEndMatchKey, absent: true, in: defaults)
        // «Подтверждать выстрел» убран 06.10 — забыть сохранённый флаг.
        defaults.removeObject(forKey: "confirmShot")
        self.ownBoardOnRight = defaults.bool(forKey: Self.ownBoardOnRightKey)
        self.soundOn = UserDefaults.standard.bool(forKey: "soundOn")
        self.musicOn = UserDefaults.standard.bool(forKey: "musicOn")
        // Как у `askLevelBeforeMatch`: отсутствующий флаг — «вкл.», в том числе
        // у тех, кто ставил игру до R4.3a.
        let hapticsOn = Self.flag(Self.hapticsOnKey, absent: true, in: defaults)
        self.hapticsOn = hapticsOn
        // `didSet` в `init` не срабатывает — сервису пишем сами.
        HapticService.shared.isEnabled = hapticsOn
        // No stored language yet — the system one, if the game speaks it.
        self.language = Self.supportedLanguage(defaults.string(forKey: Self.languageKey)
                                               ?? Locale.preferredLanguages.first)
        self.autoRevealAroundSunk = UserDefaults.standard.bool(forKey: "autoRevealAroundSunk")
        // Touching the service configures the audio session (playback category,
        // so the game is heard with the mute switch on).
        _ = AudioService.shared
    }

    /// A stored flag, or `absent` when it was never written.
    private static func flag(_ key: String, absent: Bool, in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) == nil ? absent : defaults.bool(forKey: key)
    }
}

extension String {
    /// `String(localized:)` in the game's own language (Settings → Language)
    /// rather than the system one. `\.locale` at the root reaches every `Text`,
    /// but a `String` built in code is looked up in the system language unless
    /// its resource is told otherwise. Literals passed here still land in the
    /// catalog: Xcode extracts `LocalizedStringResource` parameters.
    init(game resource: LocalizedStringResource, locale: Locale = AppState.gameLocale) {
        var resource = resource
        resource.locale = locale
        self.init(localized: resource)
    }
}
