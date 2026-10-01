//
//  OnboardingTests.swift
//  SeaBattleTests
//
//  R4.4 — первый запуск. Проверяется, кому он показывается (новичку — да,
//  игравшему до R4.4 — нет), что игрок переживает сохранение и как владелец
//  устройства садится в настройку игры вдвоём.
//

import Foundation
import Testing
@testable import SeaBattle

@Suite("Первый запуск")
struct OnboardingTests {

    @Test("Новичку онбординг показывается, игравшему до R4.4 — нет")
    func onlyNewcomersAreGreeted() {
        #expect(AppState.onboardingDone(stored: nil, isFreshInstall: true) == false)
        #expect(AppState.onboardingDone(stored: nil, isFreshInstall: false) == true)
    }

    @Test("Записанный флаг сильнее признака первого запуска")
    func storedFlagWins() {
        // Закрыл приложение на приветствии: `notFirstLaunch` уже стоит, флаг — false.
        #expect(AppState.onboardingDone(stored: false, isFreshInstall: false) == false)
        #expect(AppState.onboardingDone(stored: true, isFreshInstall: true) == true)
    }

    @Test("Игрок переживает сохранение; испорченные данные — нет игрока")
    func ownPlayerRoundTrips() throws {
        let own = OwnPlayer(name: "Аня", glyph: "crown.fill", colorIndex: 7)
        let data = try JSONEncoder().encode(own)
        #expect(OwnPlayer.decode(data) == own)
        #expect(OwnPlayer.decode(nil) == nil)
        #expect(OwnPlayer.decode(Data("{}".utf8)) == nil)
    }

    @Test("Имя без пробелов по краям; одни пробелы — нет имени")
    func trimmedName() {
        #expect(OwnPlayer(name: "  Аня ", glyph: "helm", colorIndex: 0).trimmedName == "Аня")
        #expect(OwnPlayer(name: "   ", glyph: "helm", colorIndex: 0).trimmedName.isEmpty)
    }

    @Test("Владелец садится в пустую первую карточку")
    func seatsIntoEmptyCard() {
        var setup = DuelSetup()
        setup.seat(OwnPlayer(name: " Аня ", glyph: "crown.fill", colorIndex: 5))
        #expect(setup.players[0] == DuelPlayer(name: "Аня", glyph: "crown.fill", colorIndex: 5))
        #expect(setup.players[1] == DuelSetup().players[1])
    }

    @Test("Набранное руками не перетирается, безымянный не садится")
    func doesNotOverwrite() {
        var typed = DuelSetup()
        typed.players[0].name = "Борис"
        let before = typed
        typed.seat(OwnPlayer(name: "Аня", glyph: "crown.fill", colorIndex: 5))
        #expect(typed == before)

        var empty = DuelSetup()
        empty.seat(OwnPlayer.starter)
        #expect(empty == DuelSetup())
    }

    @Test("Имя уже во второй карточке — владелец не садится")
    func sameNameAsSecondPlayer() {
        var setup = DuelSetup()
        setup.players[1].name = "аня"
        let before = setup
        setup.seat(OwnPlayer(name: "Аня", glyph: "crown.fill", colorIndex: 5))
        #expect(setup == before)
    }

    @Test("Совпали значок и цвет со вторым — второму достаются другие")
    func secondPlayerStaysDistinct() {
        var setup = DuelSetup()
        let second = setup.players[1]
        setup.seat(OwnPlayer(name: "Аня", glyph: second.glyph, colorIndex: second.colorIndex))
        #expect(setup.players[0].glyph == second.glyph)
        #expect(setup.players[1].glyph != second.glyph)
        #expect(setup.players[1].colorIndex != second.colorIndex)
    }
}
