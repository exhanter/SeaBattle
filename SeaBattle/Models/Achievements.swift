//
//  Achievements.swift
//  SeaBattle
//
//  Achievements and their medals (customer 03.11). Seven achievements, three
//  grades each — bronze, silver, gold. No points for them: they are merit,
//  shown in the player card («Личное дело») and sent to the network opponent.
//  Matches before this build do not count.
//
//  Three are secret («Меткий залп», «Ни царапины», «Шквал огня»): unseen until
//  their first grade, a surprise on the results screen. The other four are
//  counters and show from the start, with their progress.
//

import Foundation

enum MedalGrade: Int, Codable, CaseIterable, Comparable, Sendable {
    case bronze = 1, silver, gold

    var suffix: String {
        switch self {
        case .bronze: "bronze"
        case .silver: "silver"
        case .gold: "gold"
        }
    }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

enum Achievement: String, Codable, CaseIterable, Sendable {
    /// A win in at most 40 / 35 / 30 own shots, against Medium or harder.
    case sharpshooter
    /// A win without losing a ship, against Medium / Hard / Expert.
    case unscathed
    /// Ten wins in a row against Medium / Hard / Expert, counted per level.
    case streak
    /// 8 / 10 / 15 hits in a row in one match, against Medium or harder.
    case barrage
    /// 100 / 1 000 / 10 000 wins over the Expert.
    case expertSlayer
    /// 10 / 100 / 1 000 wins over people, nearby and online.
    case duelist
    /// 500 / 5 000 / 20 000 wins in any mode but the paper game.
    case seaWolf

    /// Unseen until the first grade is earned.
    var isSecret: Bool {
        switch self {
        case .sharpshooter, .unscathed, .barrage: true
        case .streak, .expertSlayer, .duelist, .seaWolf: false
        }
    }

    /// The numbers behind the three grades.
    var thresholds: [Int] {
        switch self {
        case .sharpshooter: [40, 35, 30]
        case .unscathed: [1, 1, 1]
        case .streak: [10, 10, 10]
        case .barrage: [8, 10, 15]
        case .expertSlayer: [100, 1_000, 10_000]
        case .duelist: [10, 100, 1_000]
        case .seaWolf: [500, 5_000, 20_000]
        }
    }

    /// A count that grows towards the grades — progress can be shown.
    var isCounter: Bool { self == .expertSlayer || self == .duelist || self == .seaWolf }

    /// The level a level-based grade asks for (unscathed, streak).
    static let gradeLevels: [MedalGrade: AppState.DifficultyLevel] = [
        .bronze: .medium, .silver: .hard, .gold: .expert,
    ]

    /// `medal_<id>_<grade>` without the prefix — the asset and the id sent
    /// over the network (`PlayerDossier.medals`).
    func medal(_ grade: MedalGrade) -> String { "\(rawValue)_\(grade.suffix)" }
}

/// One finished match, as the achievements need it.
struct MatchFacts: Sendable {
    let key: StatKey
    let didWin: Bool
    /// The player's shots, when the whole enemy fleet was sunk; `nil` — the
    /// match ended otherwise (the opponent left).
    let shots: Int?
    let bestStreak: Int
    let shipsLost: Int
}

/// A grade just earned — shown on the results screen.
struct EarnedMedal: Hashable, Sendable {
    let achievement: Achievement
    let grade: MedalGrade

    var medal: String { achievement.medal(grade) }
}

/// What the player has earned and the counters behind it. Lives in
/// `PlayerStats` (synced with the rest; every key read with `decodeIfPresent`).
struct AchievementBook: Codable, Hashable, Sendable {
    /// Highest grade per achievement, by `Achievement.rawValue`.
    private(set) var grades: [String: Int] = [:]
    /// Wins counted since this build: over the Expert, over people, overall.
    private(set) var expertWins = 0
    private(set) var networkWins = 0
    private(set) var totalWins = 0
    /// Current run of wins per level, by `DifficultyLevel.rawValue`.
    private(set) var streaks: [String: Int] = [:]

    init() {}

    func grade(_ achievement: Achievement) -> MedalGrade? {
        grades[achievement.rawValue].flatMap(MedalGrade.init(rawValue:))
    }

    /// Medals to show and send, most valuable first.
    var medals: [String] {
        Achievement.allCases
            .compactMap { a in grade(a).map { EarnedMedal(achievement: a, grade: $0) } }
            .sorted { $0.grade > $1.grade }
            .map(\.medal)
    }

    /// The count behind a counter achievement.
    func count(_ achievement: Achievement) -> Int {
        switch achievement {
        case .expertSlayer: expertWins
        case .duelist: networkWins
        case .seaWolf: totalWins
        case .streak: Achievement.gradeLevels.values.map { streaks[$0.rawValue] ?? 0 }.max() ?? 0
        default: 0
        }
    }

    /// Shown in the player card: earned, or visible from the start.
    func isShown(_ achievement: Achievement) -> Bool {
        !achievement.isSecret || grade(achievement) != nil
    }

    /// The grade still to earn; `nil` — gold is in.
    func nextGrade(_ achievement: Achievement) -> MedalGrade? {
        let current = grade(achievement)?.rawValue ?? 0
        return MedalGrade(rawValue: current + 1)
    }

    // MARK: Recording

    /// Counts a finished match. RETURNS: the grades it earned, to show.
    mutating func record(_ match: MatchFacts) -> [EarnedMedal] {
        var earned: [EarnedMedal] = []
        let level = match.key.difficulty
        let againstComputer = level != nil
        let mediumOrHarder = level.map { $0 != .easy } ?? false
        let againstPeople = match.key.mode == .nearby || match.key.mode == .online

        if match.didWin {
            totalWins += 1
            earned += reach(.seaWolf, count: totalWins)
            if level == .expert {
                expertWins += 1
                earned += reach(.expertSlayer, count: expertWins)
            }
            if againstPeople {
                networkWins += 1
                earned += reach(.duelist, count: networkWins)
            }
        }

        if againstComputer, let level {
            if match.didWin {
                let run = (streaks[level.rawValue] ?? 0) + 1
                streaks[level.rawValue] = run
                if let grade = Self.grade(for: level), run >= Achievement.streak.thresholds[grade.rawValue - 1] {
                    earned += raise(.streak, to: grade)
                }
                if match.shipsLost == 0, let grade = Self.grade(for: level) {
                    earned += raise(.unscathed, to: grade)
                }
            } else {
                streaks[level.rawValue] = 0
            }
        }

        if mediumOrHarder {
            if match.didWin, let shots = match.shots {
                let met = MedalGrade.allCases.filter { shots <= Achievement.sharpshooter.thresholds[$0.rawValue - 1] }
                if let best = met.max() { earned += raise(.sharpshooter, to: best) }
            }
            let met = MedalGrade.allCases.filter { match.bestStreak >= Achievement.barrage.thresholds[$0.rawValue - 1] }
            if let best = met.max() { earned += raise(.barrage, to: best) }
        }
        return earned
    }

    private static func grade(for level: AppState.DifficultyLevel) -> MedalGrade? {
        Achievement.gradeLevels.first { $0.value == level }?.key
    }

    /// Grades a counter has reached.
    private mutating func reach(_ achievement: Achievement, count: Int) -> [EarnedMedal] {
        let met = MedalGrade.allCases.filter { count >= achievement.thresholds[$0.rawValue - 1] }
        guard let best = met.max() else { return [] }
        return raise(achievement, to: best)
    }

    /// Raises the grade, never lowers it. RETURNS: the new grade, if any.
    private mutating func raise(_ achievement: Achievement, to grade: MedalGrade) -> [EarnedMedal] {
        if let current = self.grade(achievement), current >= grade { return [] }
        grades[achievement.rawValue] = grade.rawValue
        return [EarnedMedal(achievement: achievement, grade: grade)]
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case grades, expertWins, networkWins, totalWins, streaks }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grades = (try? c.decodeIfPresent([String: Int].self, forKey: .grades)) ?? [:]
        expertWins = (try? c.decodeIfPresent(Int.self, forKey: .expertWins)) ?? 0
        networkWins = (try? c.decodeIfPresent(Int.self, forKey: .networkWins)) ?? 0
        totalWins = (try? c.decodeIfPresent(Int.self, forKey: .totalWins)) ?? 0
        streaks = (try? c.decodeIfPresent([String: Int].self, forKey: .streaks)) ?? [:]
    }
}
