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
        let regular = Geometry.SizeClass.regular
        let compact = Geometry.SizeClass.compact
        #expect(regular.modeRowHeight == 58)
        #expect(regular.modeRowRadius == Geometry.Radius.button)
        #expect(compact.modeRowHeight == 52)
        // Обе цели нажатия остаются законными: строка режима — не клетка поля,
        // и правило 44 pt на неё распространяется.
        #expect(regular.modeRowHeight >= Geometry.Hit.minTarget)
        #expect(compact.modeRowHeight >= Geometry.Hit.minTarget)
        // Малый размер меньше по всем величинам сразу, а не только по высоте:
        // подогнать одну и забыть остальные — самая вероятная ошибка здесь.
        #expect(compact.modeRowRadius < regular.modeRowRadius)
        #expect(compact.modeIcon < regular.modeIcon)
        #expect(compact.modeLock < regular.modeLock)
        #expect(compact.modeName < regular.modeName)
        #expect(compact.modeSub < regular.modeSub)
        #expect(compact.modeRowPadding < regular.modeRowPadding)
        #expect(compact.modeRowGap < regular.modeRowGap)
    }

    @Test("Строка выбора: минимум 58 pt и растёт по подписи")
    func theChoiceRowGrowsWithItsSubtitle() {
        // Минимум, а не жёсткая высота: подпись занимает до двух строк без
        // обрезки (спека 2.13), а на трёх языках её длина разная.
        #expect(ControlMetrics.ChoiceRow.minHeight == 58)
        #expect(ControlMetrics.ChoiceRow.minHeight >= Geometry.Hit.minTarget)
        #expect(ControlMetrics.ChoiceRow.radius == Geometry.Radius.button)
        // Межстрочный 1,4 при кегле 12 — это +40 % к строке.
        let expectedLineSpacing: CGFloat = 12 * 0.4
        #expect(ControlMetrics.ChoiceRow.subtitleLineSpacing == expectedLineSpacing)
    }

    @Test("Выбранная панель светится вместо тени, и только выбранная")
    func onlyTheSelectedPanelGlows() {
        // Свечение **вместо** тени (спека 2.13): вдвоём латунный ободок тонет
        // в тёмном ореоле. Проверяется признак, на который смотрит панель.
        #expect(GlassHighlight.selected.isSelected)
        #expect(!GlassHighlight.none.isSelected)
    }

    @Test("Строка возврата и NavRow дотягиваются до 44 pt")
    func theNavigationChromeIsTappable() {
        // `NavRow` в макете был 41 pt — ошибка макета, дизайн прислал 44.
        #expect(Geometry.Nav.rowHeight == Geometry.Hit.minTarget)
        #expect(Geometry.Nav.rowRadius == 20)
        // Заголовок отсчитан от края экрана, а не от безопасной зоны.
        #expect(Geometry.Nav.titleTop == 68)
        #expect(NavMetrics.titleTopBelowSafeArea > 0)
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
