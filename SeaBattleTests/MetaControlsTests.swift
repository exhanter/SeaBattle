//
//  MetaControlsTests.swift
//  SeaBattleTests
//
//  R1.5b — контролы мета-экранов. Проверяется то, что считается, а не то, что
//  рисуется: состав палитры игрока, доля побед и связь языка с буквами поля.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("Контролы мета-экранов")
@MainActor
struct MetaControlsTests {

    @Test("Палитра игрока: 10 значков и 16 цветов, без повторов")
    func thePlayerPaletteIsComplete() {
        #expect(PlayerAvatar.glyphs.count == 10)
        #expect(PlayerAvatar.colors.count == 16)
        #expect(Set(PlayerAvatar.glyphs).count == 10, "значки не должны повторяться")
        // Первый цвет — латунь: он же по умолчанию, и он же цвет роли «ты».
        #expect(PlayerAvatar.colors.first == Color(hex: 0xD19A3C))
    }

    @Test("Кнопки значка и цвета — 46 pt, выше минимальной цели нажатия")
    func theAvatarButtonsAreBigEnough() {
        #expect(PlayerAvatar.buttonSide == 46)
        #expect(PlayerAvatar.buttonSide >= Geometry.Hit.minTarget)
    }

    @Test("Пустая история — это не половина побед")
    func anEmptyHistoryIsNotHalfWins() {
        // Ноль из нуля легко превратить в 50 % делением, и полоса покажет
        // ровно половину там, где игрок ещё не сыграл ни разу.
        let empty = StatBar(wins: 0, losses: 0)
        #expect(empty.total == 0)
        #expect(empty.winShare == 0)
    }

    @Test("Доля побед считается от всех партий")
    func theWinShareCountsEveryGame() {
        let bar = StatBar(wins: 37, losses: 21)
        #expect(bar.total == 58)
        #expect(abs(bar.winShare - 37.0 / 58.0) < 0.0001)

        let perfect = StatBar(wins: 5, losses: 0)
        #expect(perfect.winShare == 1)
    }

    @Test("Язык определяет буквы поля, и это видно до переключения")
    func theLanguageDecidesTheBoardLetters() {
        let languages = LanguageMenu.languages
        #expect(languages.count == 3)
        #expect(languages.map(\.id) == ["ru", "en", "nl"])
        // Подпись в пункте меню — не украшение: от языка зависит разметка
        // координат поля, и игрок должен увидеть это заранее.
        #expect(languages[0].letters == "А–К")
        #expect(languages[1].letters == "A–J")
        #expect(languages[2].letters == "A–J")
        #expect(languages[0].alphabet == .cyrillic)
        #expect(languages[2].alphabet == .latin)
    }

    @Test("Достижение различает полученное и недостигнутое")
    func anAchievementKnowsWhetherItIsEarned() {
        #expect(AchievementRow.State.earned(points: 40) != .inProgress(current: 40, total: 40))
        #expect(AchievementRow.State.earned(points: 40) == .earned(points: 40))
    }
}
