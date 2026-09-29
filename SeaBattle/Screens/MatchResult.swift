//
//  MatchResult.swift
//  Sea Battle — итоги партии без SwiftUI (R2.5)
//
//  Спека 4.9, кадр `screen10Result`. Экран итогов показывает три блока:
//  результат со счётом по флотам, начисление баллов чеком и «Как шла
//  партия». Всё, что в них пишется, считается здесь: правил тут немного, но
//  каждое молчит при поломке — строка за исход при поражении, подсказки,
//  потерянные после «Продолжить партию», серия, не оборванная промахом.
//

import Foundation

// MARK: - Счёт партии

/// Что игрок сделал за партию — ровно то, чего нет на доске. Выстрелы по
/// доске не пересчитать: обводка потопленного промахами ставит воронки, по
/// которым никто не стрелял, а подсказки на доске не остаются вовсе.
///
/// Пишется в сохранение (`GameSnapshot.tally`): иначе «Продолжить партию»
/// после перезапуска обнуляла бы и точность, и списание за подсказки.
struct MatchTally: Codable, Equatable, Sendable {
    /// Все выстрелы игрока, повторные тоже: ход они тратят так же.
    private(set) var shots = 0
    /// Попадания и потопления. Повторное попадание не считается — корабль от
    /// него не пострадал.
    private(set) var hits = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var hintsUsed = 0
    /// Сумма, а не число × цена: цена подсказки — ставка уровня, и если её
    /// когда-нибудь сделают одной на всех, прошлые партии не пересчитаются.
    private(set) var hintPointsSpent = 0

    mutating func record(_ result: Board.ShotResult) {
        switch result {
        case .hit, .sunk:
            shots += 1
            hits += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        case .miss, .repeated:
            shots += 1
            streak = 0
        case .offBoard:
            break
        }
    }

    mutating func recordHint(cost: Int) {
        hintsUsed += 1
        hintPointsSpent += cost
    }

    /// Доля попаданий; `nil`, пока выстрелов не было.
    var accuracy: Double? {
        shots > 0 ? Double(hits) / Double(shots) : nil
    }
}

// MARK: - Строка начисления

/// Одна строка чека (4.9): за победу, за достижения, закрытые в этой
/// партии, минус за подсказки. Достижений пока нет — они приходят с экраном
/// статистики (R4.1), и строка для них встанет сюда же.
enum PointLine: Equatable, Sendable {
    case victory(points: Int)
    case hints(count: Int, points: Int)

    /// Со знаком: списание отрицательное.
    var amount: Int {
        switch self {
        case .victory(let points): points
        case .hints(_, let points): -points
        }
    }
}

// MARK: - Итог

struct MatchResult: Equatable, Sendable {
    let didWin: Bool
    let level: AppState.DifficultyLevel
    /// Сколько кораблей потеряли вы — тёплое на экране.
    let yourLosses: Int
    /// Сколько потопили вы — холодное.
    let foeLosses: Int
    let fleetSize: Int
    let tally: MatchTally
    /// Баланс **после** партии: победа уже начислена, подсказки уже списаны.
    let balance: Int

    init(didWin: Bool, level: AppState.DifficultyLevel,
         yourLosses: Int, foeLosses: Int,
         fleetSize: Int = FleetLayout.shipCount,
         tally: MatchTally, balance: Int) {
        self.didWin = didWin
        self.level = level
        self.yourLosses = yourLosses
        self.foeLosses = foeLosses
        self.fleetSize = fleetSize
        self.tally = tally
        self.balance = balance
    }

    /// Строки чека по порядку. **При поражении строки за исход нет** (4.9):
    /// не «Поражение 0», а ничего — нулевая строка читается как штраф.
    var lines: [PointLine] {
        var lines: [PointLine] = []
        let reward = StatKey.computer(level).pointsForWin
        if didWin && reward > 0 {
            lines.append(.victory(points: reward))
        }
        if tally.hintsUsed > 0 {
            lines.append(.hints(count: tally.hintsUsed, points: tally.hintPointsSpent))
        }
        return lines
    }

    /// Итог партии в баллах — число в шапке чека.
    var net: Int { lines.reduce(0) { $0 + $1.amount } }
}

extension MatchResult {
    /// Число со знаком для шапки чека: «+60», «−5», «0». Минус — типографский,
    /// как в макете и на кнопке подсказки.
    static func signed(_ value: Int) -> String {
        switch value {
        case 1...: "+\(value)"
        case ..<0: "\u{2212}\(-value)"
        default: "0"
        }
    }
}
