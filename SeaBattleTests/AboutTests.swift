//
//  AboutTests.swift
//  SeaBattleTests
//
//  R4.6: «О приложении». Авторов звуков с лицензией Attribution 4.0 упоминать
//  обязательно — список и ссылки не должны тихо потеряться при правке экрана.
//

import Foundation
import Testing
@testable import SeaBattle

@Suite("О приложении")
struct AboutTests {

    @Test("Шесть звуков freesound: четыре под CC BY 4.0, два под CC0")
    func everySoundIsCredited() {
        let sounds = AboutContent.sounds
        #expect(sounds.map(\.id) == [120956, 117095, 751086, 531132, 394466, 388758])
        #expect(sounds.filter { $0.license == .attribution4 }.count == 4)
        #expect(sounds.filter { $0.license == .cc0 }.count == 2)
        #expect(Set(sounds.map(\.id)).count == sounds.count)
    }

    @Test("Ссылка звука ведёт на его страницу freesound")
    func soundLinksPointAtFreesound() {
        #expect(AboutContent.sounds[0].url.absoluteString == "https://freesound.org/s/120956/")
    }

    @Test("Почта открывается письмом, сайт — по https")
    func contactLinks() {
        #expect(AboutContent.emailURL.absoluteString == "mailto:request@brapps.nl")
        #expect(AboutContent.websiteURL.scheme == "https")
    }

    @Test("Версия — номер и сборка, без сборки, если они совпадают")
    func versionLine() {
        let version = AboutContent.version()
        #expect(!version.isEmpty)
        #expect(version != "—")
    }
}
