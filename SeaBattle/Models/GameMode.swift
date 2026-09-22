//
//  GameMode.swift
//  SeaBattle
//
//  R0.7: the five ways a match can be played, in the order the menu lists them
//  (spec 4.2), and the statistics row a finished match belongs to.
//
//  Before R0.7 every network win was written as a win over the computer's
//  expert level (audit finding A7), because that was the only column the store
//  had. The design shows the modes apart (spec 4.9), so the store now keeps one
//  record per row.
//

import Foundation

enum GameMode: String, Codable, CaseIterable, Sendable {
    /// Against the computer — the only mode split further, by difficulty.
    case computer
    /// Paper game: the app keeps the board of a match played against a person
    /// on paper, so it never sees the opponent's fleet.
    case paper
    /// Two players sharing one device.
    case hotSeat
    /// Two devices over Multipeer, no internet needed.
    case nearby
    /// Two devices over Game Center.
    case online

    /// Whether finished matches in this mode are written to the saved
    /// statistics. Hot-seat is not: the design keeps only the score of the
    /// current series, which lives in `HotSeatGame` and dies with it
    /// (spec 4.9, "статистика «вдвоём на устройстве» — только счёт серии").
    var isTracked: Bool { self != .hotSeat }
}

/// One row of the statistics: a mode, and for the computer also the level.
///
/// `storageKey` is what ends up in the persisted dictionary and in the CloudKit
/// record, so the strings are frozen — renaming a case is fine, changing a raw
/// value silently orphans everybody's history.
enum StatKey: Hashable, Sendable {
    case computer(AppState.DifficultyLevel)
    case paper
    case hotSeat
    case nearby
    case online

    var mode: GameMode {
        switch self {
        case .computer: return .computer
        case .paper: return .paper
        case .hotSeat: return .hotSeat
        case .nearby: return .nearby
        case .online: return .online
        }
    }

    /// The level, for rows of the computer mode; `nil` for everything else.
    var difficulty: AppState.DifficultyLevel? {
        if case .computer(let level) = self { return level }
        return nil
    }

    var storageKey: String {
        if let difficulty { return "computer.\(difficulty.rawValue)" }
        return mode.rawValue
    }

    /// Points a win in this row pays out. Beating a person over the network pays
    /// the expert rate, exactly as it did before R0.7 — only the column it is
    /// counted in has changed.
    ///
    /// The paper game pays nothing: the app cannot see that board, so the result
    /// is whatever the player types in, and paying for it would be paying for a
    /// button press. Hot-seat pays nothing for the same reason it is not
    /// tracked — both players are one account.
    var pointsForWin: Int {
        switch self {
        case .computer(let level): return level.pointsValue
        case .paper, .hotSeat: return 0
        case .nearby, .online: return AppState.DifficultyLevel.expert.pointsValue
        }
    }

    /// Every row the statistics screen can show, in menu order. Hot-seat is
    /// absent by design — see `GameMode.isTracked`.
    static let tracked: [StatKey] = [
        .computer(.easy), .computer(.medium), .computer(.hard), .computer(.expert),
        .paper, .nearby, .online
    ]
}

/// Wins and losses in one statistics row.
struct StatRecord: Codable, Hashable, Sendable {
    var wins: Int = 0
    var losses: Int = 0

    var played: Int { wins + losses }

    /// Share of games won, 0…1, or `nil` when the row is empty — the design
    /// leaves empty rows as dashes rather than showing 0%.
    var winShare: Double? {
        played > 0 ? Double(wins) / Double(played) : nil
    }
}
