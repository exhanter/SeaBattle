//
//  BackgroundAndGlassTests.swift
//  SeaBattleTests
//
//  R1.2 — фон и стекло. Проверяется не вид, а числа: таблица трёх уровней
//  стекла из спеки 2.2 и правило Reduce Motion для дыхания. Вид сверяется
//  превью в `SeaBackground.swift` и `GlassPanel.swift`, но значения глазами не
//  проверить — 1 pt обводки от 1,5 pt на скриншоте не отличить.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("Фон и стекло")
struct BackgroundAndGlassTests {

    // MARK: - Дыхание свечения

    @Test("Выдох и вдох — ровно те значения, что в спеке")
    func breathingEndpointsMatchTheSpec() {
        #expect(BreathState.resting.scale == 1.04)
        #expect(BreathState.resting.offsetFraction == 0)
        #expect(BreathState.resting.opacity == 0.9)

        #expect(BreathState.inhaled.scale == 1.10)
        #expect(BreathState.inhaled.offsetFraction == -0.02)
        #expect(BreathState.inhaled.opacity == 1.0)

        #expect(Motion.breathe == 18.0)
    }

    @Test("Reduce Motion: слой замирает на середине и не исчезает")
    func reduceMotionFreezesTheGlowWithoutHidingIt() {
        // Главное в этом правиле — «не исчезает»: свечение часть картинки, а не
        // украшение, поэтому прозрачность полная, а не средняя между 0,9 и 1.
        #expect(BreathState.frozen.scale == 1.07)
        #expect(BreathState.frozen.offsetFraction == 0)
        #expect(BreathState.frozen.opacity == 1.0)

        // При включённом Reduce Motion фаза цикла не имеет значения.
        #expect(BreathState.state(reduceMotion: true, inhaled: false) == .frozen)
        #expect(BreathState.state(reduceMotion: true, inhaled: true) == .frozen)
    }

    @Test("Без Reduce Motion состояние следует фазе цикла")
    func withoutReduceMotionTheStateFollowsThePhase() {
        #expect(BreathState.state(reduceMotion: false, inhaled: false) == .resting)
        #expect(BreathState.state(reduceMotion: false, inhaled: true) == .inhaled)
    }

    @Test("Замершее значение — середина между вдохом и выдохом")
    func theFrozenScaleSitsBetweenTheEndpoints() {
        let mid = (BreathState.resting.scale + BreathState.inhaled.scale) / 2
        #expect(BreathState.frozen.scale == mid)
    }

    // MARK: - Уровни стекла

    @Test("G1 — глухой слой: ни блюра, ни блика, ни тени")
    func theSolidLevelHasNothingToSeeThrough() {
        let g1 = GlassLevel.g1.spec
        #expect(g1.hasMaterial == false)
        #expect(g1.hasSheen == false)
        #expect(g1.hasShadow == false)
        #expect(g1.strokeWidth == 1)
    }

    @Test("G2 — обводка 1 pt, блик 1 pt, тень 0 8 24")
    func thePanelLevelMatchesTheSpec() {
        let g2 = GlassLevel.g2.spec
        #expect(g2.hasMaterial)
        #expect(g2.strokeWidth == 1)
        #expect(g2.sheenWidth == 1)
        // CSS `0 8 24` → SwiftUI radius 12, y 8: в CSS размытие задаётся
        // диаметром, в SwiftUI — радиусом.
        #expect(g2.shadowRadius == 12)
        #expect(g2.shadowOffsetY == 8)
    }

    @Test("G3 — обводка 1,5 pt, блик 2 pt, тень 0 10 30")
    func theRaisedLevelMatchesTheSpec() {
        let g3 = GlassLevel.g3.spec
        #expect(g3.hasMaterial)
        #expect(g3.strokeWidth == 1.5)
        #expect(g3.sheenWidth == 2)
        #expect(g3.shadowRadius == 15)
        #expect(g3.shadowOffsetY == 10)
    }

    @Test("Приподнятый слой заметнее обычного")
    func theRaisedLevelReadsAboveThePanel() {
        // Это свойство, а не совпадение: G3 лежит над G2, поэтому и обводка, и
        // блик, и тень у него сильнее. Если однажды числа сойдутся — слои
        // перестанут различаться на глаз.
        let g2 = GlassLevel.g2.spec, g3 = GlassLevel.g3.spec
        #expect(g3.strokeWidth > g2.strokeWidth)
        #expect(g3.sheenWidth > g2.sheenWidth)
        #expect(g3.shadowRadius > g2.shadowRadius)
        #expect(g3.shadowOffsetY > g2.shadowOffsetY)
    }

    @Test("Деревянный кант ложится на кромку, обращённую к морю")
    func theWoodEdgeSitsOnTheSideFacingTheSea() {
        // Верхняя панель получает кант по низу, нижняя — по верху; левых и
        // правых кантов в системе нет вовсе, поэтому вариантов ровно три.
        #expect(WoodEdge.bottom.alignment == .bottom)
        #expect(WoodEdge.top.alignment == .top)
        #expect(Geometry.woodEdge == 2)
    }
}
