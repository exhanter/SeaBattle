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
        // Токены, у которых значение по замыслу одно на обе темы — прочерк в
        // светлой колонке `docs/design/TOKENS.md`. Корпус и огонь поверх него
        // сюда входят: свой корабль всегда песочный, поэтому и пламя на нём одно.
        let expectedFlat: Set<String> = [
            "Role/You", "Role/Foe", "Role/YouSoft",
            "Chrome/Wood", "Chrome/WoodDeep", "Chrome/Fire",
            "Ink/Primary", "Ink/Secondary", "Ink/Tertiary", "Ink/OnBrass",
            "Cell/HullSandLight", "Cell/HullSand", "Cell/HullSandDark",
            "Cell/HullDeniedLight", "Cell/HullDenied", "Cell/HullDeniedDark",
            "Cell/HullSheen", "Cell/HullShade",
            "Cell/HitTintMulTop", "Cell/HitTintMulBottom",
            "Cell/HitTintScrTop", "Cell/HitTintScrBottom",
            "Cell/HitWarmIn", "Cell/HitWarmOut",
            "Cell/HitCross", "Cell/HitCrossShadow",
            "Cell/SteelTop", "Cell/SteelMid", "Cell/SteelBottom",
            "Cell/SteelSheen", "Cell/SteelShade", "Cell/SunkCrossEdge",
            // `Button/BrassTop` и `BrassBottom` здесь больше НЕТ: с раунда 4
            // у них своя латунь для светлой темы — прежняя полупрозрачная не
            // держала белую надпись на светлом море.
            "Button/Sheen", "Button/Shade", "Button/Shadow", "Button/TextShadow",
            "Warn/Icon",
            "Board/FillYou", "Board/FillFoe", "Board/StrokeYou", "Board/StrokeFoe",
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

    @Test("Крест пробоины и его обводка меняются ролями по темам")
    func fireCrossSwapsWithItsEdge() throws {
        let cross = try #require(UIColor(named: ColorToken.fireCross.rawValue, in: .main, compatibleWith: nil))
        let edge = try #require(UIColor(named: ColorToken.fireCrossEdge.rawValue, in: .main, compatibleWith: nil))
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)
        // В тёмной теме крест светлый на тёмной обводке, в светлой — наоборот:
        // белый крест на светлом море потерялся бы.
        #expect(cross.resolvedColor(with: dark).brightness > edge.resolvedColor(with: dark).brightness)
        #expect(cross.resolvedColor(with: light).brightness < edge.resolvedColor(with: light).brightness)
    }

    @Test("Свечение фона в светлой теме светлее, чем в тёмной")
    func glowStaysLightInTheLightTheme() throws {
        let glow = try #require(UIColor(named: ColorToken.seaGlow.rawValue, in: .main, compatibleWith: nil))
        let light = glow.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = glow.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        // На светлом бирюзовом море тёмная бирюза не читается: свет снизу
        // должен остаться светом.
        #expect(light.brightness > dark.brightness)
    }

    @Test("Группы галереи покрывают все токены без потерь")
    func galleryGroupsCoverEveryToken() {
        let grouped = ColorToken.groups.flatMap(\.tokens)
        #expect(grouped.count == ColorToken.allCases.count)
        #expect(Set(grouped) == Set(ColorToken.allCases))
        #expect(ColorToken.groups.map(\.name)
                == ["Sea", "Role", "Chrome", "Glass", "Ink", "Cell", "Board",
                    "Button", "Warn", "Overlay"])
    }

    @Test("Перечисление описывает весь каталог: 81 токен")
    func theEnumCoversTheWholeCatalogue() {
        // Каталог приходит из пакета дизайна готовым, а перечисление ведём мы,
        // поэтому число зафиксировано: пришёл новый пакет — сверить и поправить.
        #expect(ColorToken.allCases.count == 81)
    }

    @Test("Заливка G2 в тёмной теме ровная, в светлой — с перепадом")
    func theG2FillIsFlatInTheDarkTheme() throws {
        let fill = try #require(UIColor(named: ColorToken.glassFill.rawValue, in: .main, compatibleWith: nil))
        let fill2 = try #require(UIColor(named: ColorToken.glassFill2.rawValue, in: .main, compatibleWith: nil))
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)
        // Панель всегда заливается градиентом `Fill → Fill2`, ветки по теме
        // запрещены. Ровной в тёмной теме она выглядит потому, что там обе
        // точки равны, — иначе на панелях разной высоты низ светлел бы по-разному.
        #expect(fill.resolvedColor(with: dark) == fill2.resolvedColor(with: dark))
        #expect(fill.resolvedColor(with: light) != fill2.resolvedColor(with: light))
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
