//
//  SettingsTests.swift
//  SeaBattleTests
//
//  R4.2 — настройки. Проверяется перевод сохранённого языка: старые сборки
//  писали `"EN"`, `"NL"` или системный идентификатор, новый список знает
//  только `ru`, `en`, `nl`.
//

import Testing
@testable import SeaBattle

@Suite("Настройки")
@MainActor
struct SettingsTests {

    @Test("Старые значения языка читаются как коды списка",
          arguments: [("EN", "en"), ("NL", "nl"), ("ru_NL", "ru"), ("en_US", "en"),
                      ("nl-BE", "nl"), ("ru", "ru")])
    func storedLanguagesMapToSupportedCodes(stored: String, expected: String) {
        #expect(AppState.supportedLanguage(stored) == expected)
    }

    @Test("Язык, которого в игре нет, и пустое значение — английский")
    func unsupportedLanguagesReadAsEnglish() {
        #expect(AppState.supportedLanguage("de_DE") == "en")
        #expect(AppState.supportedLanguage(nil) == "en")
        #expect(AppState.supportedLanguage("") == "en")
    }

    @Test("Список языка и модель знают одни и те же коды")
    func theMenuAndTheModelAgree() {
        #expect(LanguageMenu.languages.map(\.id) == AppState.supportedLanguages)
    }
}
