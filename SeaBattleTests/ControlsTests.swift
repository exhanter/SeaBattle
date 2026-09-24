//
//  ControlsTests.swift
//  SeaBattleTests
//
//  R1.5a — контролы. Проверяются числа из спеки: их легко сдвинуть при правке
//  вёрстки, и на скриншоте разница в две точки не видна, а в ряду из пяти
//  строк меню — уже да.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("Контролы")
struct ControlsTests {

    @Test("Главная кнопка: радиус 18 и общее гашение неактивной")
    func thePrimaryButtonFollowsTheSpec() {
        #expect(ControlMetrics.Button.radius == 18)
        #expect(ControlMetrics.Button.radius == Geometry.Radius.button)
        // Неактивная кнопка гаснет целиком, а не по частям: отдельного набора
        // цветов для выключенного состояния в системе нет.
        #expect(ControlMetrics.Button.disabledOpacity == 0.38)
        #expect(ControlMetrics.Button.minHeight >= Geometry.Hit.minTarget)
    }

    @Test("Тень кнопки переведена из CSS правильно")
    func theButtonShadowMatchesTheSpec() {
        // Спека: тень наружу `0 6 18`. В CSS размытие задаётся диаметром,
        // в SwiftUI — радиусом, поэтому 18 превращается в 9.
        #expect(ControlMetrics.Button.shadowOffsetY == 6)
        #expect(ControlMetrics.Button.shadowRadius == 9)
        #expect(ControlMetrics.Button.haloRadius == 22)
    }

    @Test("Строка режима: 58 pt на большом экране, 52 на малом, обе под палец")
    func theModeRowHasTwoSizes() {
        let regular = ControlMetrics.ModeRow.regular
        let compact = ControlMetrics.ModeRow.compact
        #expect(regular.height == 58)
        #expect(regular.radius == Geometry.Radius.button)
        // 52 pt — из кадра `screenSmallMenu`. Спека в 2.11 называет только 58,
        // числа малого размера вычитаны из исходника макета (вопрос В7).
        #expect(compact.height == 52)
        // Обе цели нажатия остаются законными: строка режима — не клетка поля,
        // и правило 44 pt на неё распространяется.
        #expect(regular.height >= Geometry.Hit.minTarget)
        #expect(compact.height >= Geometry.Hit.minTarget)
        // Малый размер меньше по всем величинам сразу, а не только по высоте:
        // подогнать одну и забыть остальные — самая вероятная ошибка здесь.
        #expect(compact.radius < regular.radius)
        #expect(compact.iconSize < regular.iconSize)
        #expect(compact.lockSize < regular.lockSize)
        #expect(compact.titleSize < regular.titleSize)
        #expect(compact.subtitleSize < regular.subtitleSize)
        #expect(compact.horizontalPadding < regular.horizontalPadding)
        #expect(compact.spacing < regular.spacing)
    }

    @Test("Сегмент вписан в обойму, а не торчит из неё")
    func theSegmentFitsItsContainer() {
        // Радиус обоймы = радиус сегмента + отступ: иначе внутренний угол
        // окажется острее внешнего и переключатель будет выглядеть склеенным.
        let inner = ControlMetrics.Segment.radius
        let padding = ControlMetrics.Segment.padding
        // Ожидаемое значение — явной величиной: в `#expect` арифметика из голых
        // литералов типизируется как Int и сравнение с CGFloat разъезжается,
        // хотя обе стороны равны (см. `docs/STATUS.md`).
        let containerRadius: CGFloat = 16
        #expect(inner + padding == containerRadius)
        #expect(padding == CGFloat(3))
        // Цель нажатия: видимый сегмент 44 pt, обойма по 3 pt — всего 50 pt.
        // В макетах переключатель 40 pt, это ошибка макета; дизайн подтвердил
        // 44 pt и прислал значение как `Geometry.Segment.height`.
        #expect(ControlMetrics.Segment.minHeight == Geometry.Hit.minTarget)
        #expect(ControlMetrics.Segment.minHeight + padding * 2 == CGFloat(50))
    }
}
