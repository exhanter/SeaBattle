//
//  DesignTokensTests.swift
//  SeaBattleTests
//
//  Токен, которого нет в каталоге, молчит: `Color("Sea/Top")` не падает и не
//  предупреждает, а просто рисует не тем цветом. Поэтому каждое имя из
//  `ColorToken` проверяется здесь — это единственное место, где опечатка в
//  ассете превращается в красный тест, а не в странный оттенок на экране.
//

import Testing
import SwiftUI
import UIKit
@testable import SeaBattle

@Suite("Токены дизайн-системы")
struct DesignTokensTests {

    @Test("Каждый токен есть в Colors.xcassets")
    func everyTokenResolves() {
        let missing = ColorToken.allCases.filter {
            UIColor(named: $0.rawValue, in: .main, compatibleWith: nil) == nil
        }
        #expect(missing.isEmpty, "нет в каталоге: \(missing.map(\.rawValue).joined(separator: ", "))")
    }

    @Test("У каждого токена есть вариант для светлой и для тёмной темы")
    func everyTokenHasBothAppearances() {
        var flat: [String] = []
        for token in ColorToken.allCases {
            guard let color = UIColor(named: token.rawValue, in: .main, compatibleWith: nil) else {
                continue  // отсутствие ловит отдельный тест
            }
            let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            // Ассет без варианта Dark отдаёт один и тот же объект на оба трейта.
            // Это законно для токенов, у которых значение одно на обе темы
            // (латунь, лазурь, дерево, корпус), поэтому просто собираем список
            // и сверяем его с ожидаемым ниже.
            if light == dark { flat.append(token.rawValue) }
        }
        // Токены, у которых значение по замыслу одно на обе темы (таблица 15b:
        // прочерк в светлой колонке) плюс корпуса и тинты огня из макетов.
        let expectedFlat: Set<String> = [
            "Role/You", "Role/Foe", "Role/YouSoft",
            "Chrome/Wood", "Chrome/Fire",
            "Ink/Primary", "Ink/Secondary", "Ink/Tertiary", "Ink/OnBrass",
            "Cell/HullSandLight", "Cell/HullSand", "Cell/HullSandDark",
            "Cell/HullFoeLight", "Cell/HullFoe", "Cell/HullFoeDark",
            "Cell/HullDeniedLight", "Cell/HullDenied", "Cell/HullDeniedDark",
            "Cell/HullSheen", "Cell/HullShade", "Cell/HullCross",
            "Cell/FireTintTop", "Cell/FireTintBottom",
            "Cell/FireSatTop", "Cell/FireSatBottom",
            "Cell/FireWarmIn", "Cell/FireWarmOut", "Cell/FireCrossShadow",
            "Cell/SteelTop", "Cell/SteelMid", "Cell/SteelBottom",
            "Cell/SteelSheen", "Cell/SteelShade", "Cell/SunkCrossEdge",
        ]
        #expect(Set(flat) == expectedFlat,
                "тема различается не у тех токенов: лишние \(Set(flat).subtracting(expectedFlat)), недостающие \(expectedFlat.subtracting(Set(flat)))")
    }

    @Test("Море в тёмной теме темнее, чем в светлой")
    func seaIsDarkerInDarkTheme() throws {
        for token in [ColorToken.seaTop, .seaMid, .seaBottom] {
            let color = try #require(UIColor(named: token.rawValue, in: .main, compatibleWith: nil))
            let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            #expect(dark.brightness < light.brightness, "\(token.rawValue)")
        }
    }

    @Test("Роли не путаются: своя латунь тёплая, чужая лазурь холодная")
    func rolesKeepTheirTemperature() throws {
        let you = try #require(UIColor(named: ColorToken.roleYou.rawValue, in: .main, compatibleWith: nil))
        let foe = try #require(UIColor(named: ColorToken.roleFoe.rawValue, in: .main, compatibleWith: nil))
        var youHue: CGFloat = 0, foeHue: CGFloat = 0
        var s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        you.getHue(&youHue, saturation: &s, brightness: &b, alpha: &a)
        foe.getHue(&foeHue, saturation: &s, brightness: &b, alpha: &a)
        // Латунь лежит в жёлтой части круга, лазурь — в синей.
        #expect(youHue * 360 > 20 && youHue * 360 < 60)
        #expect(foeHue * 360 > 190 && foeHue * 360 < 230)
    }

    @Test("Группы галереи покрывают все токены без потерь")
    func galleryGroupsCoverEveryToken() {
        let grouped = ColorToken.groups.flatMap(\.tokens)
        #expect(grouped.count == ColorToken.allCases.count)
        #expect(Set(grouped) == Set(ColorToken.allCases))
        #expect(ColorToken.groups.map(\.name) == ["Sea", "Role", "Chrome", "Glass", "Ink", "Cell"])
    }

    @Test("Радиус клетки — 26 % размера, но не меньше 4 pt")
    func cellRadiusFollowsSize() {
        #expect(Geometry.cellRadius(for: 32) == 8)
        #expect(Geometry.cellRadius(for: 28) == 7)
        #expect(Geometry.cellRadius(for: 42) == 11)
        #expect(Geometry.cellRadius(for: 46) == 12)
        #expect(Geometry.cellRadius(for: 8) == 4)   // пол работает
    }

    @Test("Reduce Motion делит длительности пополам")
    func reduceMotionHalvesDurations() {
        #expect(Motion.scaled(Motion.splash, reduceMotion: false) == 0.240)
        #expect(Motion.scaled(Motion.splash, reduceMotion: true) == 0.120)
    }
}

private extension UIColor {
    /// Яркость по восприятию — этого хватает, чтобы сравнить две темы.
    var brightness: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}
