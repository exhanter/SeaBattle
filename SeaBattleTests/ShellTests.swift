//
//  ShellTests.swift
//  SeaBattleTests
//
//  R2.1 — навигация и меню. Проверяется то, что молчит при поломке: состав и
//  порядок списка режимов, кто из них под замком, размеры таб-бара и разбор
//  «Продолжить партию». Ошибка в любом из этих мест оставляет сборку зелёной.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("Оболочка и меню")
struct ShellTests {

    // MARK: Табы

    @Test("Табов три, премиума среди них нет")
    func theNavigationHasThreeTabs() {
        #expect(ShellTab.allCases.count == 3)
        #expect(ShellTab.allCases == [.play, .statistics, .settings])
        // Пейволл открывается из строки с замком и из настроек. Появившийся
        // здесь таб премиума — расхождение со спекой 3, а не мелочь вёрстки:
        // из-за него приложение начинает продавать раньше, чем играть.
        #expect(!ShellTab.allCases.contains { $0.rawValue.contains("premium") })
    }

    @Test("Таб-бар: 68 pt на большом экране, 56 на малом, обе цели под палец")
    func theTabBarFollowsTheMockup() {
        #expect(TabBarSize.regular.height == 68)
        #expect(TabBarSize.regular.radius == Geometry.Radius.panelLarge)
        #expect(TabBarSize.compact.height == 56)
        #expect(TabBarSize.regular.height >= Geometry.Hit.minTarget)
        #expect(TabBarSize.compact.height >= Geometry.Hit.minTarget)
        #expect(TabBarMetrics.inactiveOpacity == 0.62)
    }

    @Test("Размер таб-бара выбирается по той же границе, что раскладка меню")
    func theTabBarSwitchesWithTheMenu() {
        // Разъехавшиеся границы дали бы малый таб-бар под большим меню — и
        // наоборот; на одном устройстве из семи это выглядело бы случайным.
        #expect(TabBarSize.forWidth(393) == .regular)
        #expect(TabBarSize.forWidth(375) == .compact)
        #expect(MenuLayout.forWidth(393) == .regular)
        #expect(MenuLayout.forWidth(375) == .compact)
    }

    // MARK: Список режимов

    @Test("Меню перечисляет все пять режимов в порядке модели")
    func theMenuListsEveryModeInOrder() {
        // Порядок строк — это спека 4.2, и он же порядок граф статистики.
        // Список в меню строится из `GameMode.allCases`, поэтому разъехаться
        // им нечем; тест сторожит именно это.
        #expect(MenuMode.all.map(\.mode) == GameMode.allCases)
        #expect(MenuMode.all.count == 5)
    }

    @Test("Бесплатны ровно одиночная игра и игра на бумаге")
    func onlyTheFirstTwoModesAreFree() {
        let free = MenuMode.all.filter(\.isFree).map(\.mode)
        #expect(free == [.computer, .paper])
    }

    @Test("Без Pro замок стоит у трёх режимов игры с людьми, с Pro — ни у кого")
    func locksFollowThePurchase() {
        let locked = MenuMode.all.filter { $0.isLocked(isPremium: false) }.map(\.mode)
        #expect(locked == [.hotSeat, .nearby, .online])

        let lockedForSubscriber = MenuMode.all.filter { $0.isLocked(isPremium: true) }
        #expect(lockedForSubscriber.isEmpty)
    }

    @Test("У каждой строки есть иконка")
    func everyRowHasAnIcon() {
        for item in MenuMode.all {
            #expect(!item.icon.isEmpty, "у режима \(item.mode.rawValue) нет иконки")
        }
    }

    // MARK: Фото в мате

    @Test("Фото: 252 pt на большом экране, 170 pt на 375")
    func thePhotoKeepsItsTwoSizes() {
        #expect(MenuLayout.forWidth(393).heroSide == 252)
        #expect(MenuLayout.forWidth(430).heroSide == 252)
        #expect(MenuLayout.forWidth(375).heroSide == 170)
        #expect(MenuLayout.forWidth(320).heroSide == 170)
    }

    @Test("Внутренний радиус мата меньше внешнего ровно на толщину мата")
    func theMatCornersNest() {
        // Иначе угол фотографии либо вылезает за мат, либо оставляет просвет —
        // на скриншоте это пара точек, глазами не ловится. Оба радиуса
        // переписаны из кадров как отдельные числа, поэтому проверка заодно
        // говорит, что кадры согласованы и переписаны верно.
        for layout in [MenuLayout.regular, .compact] {
            let expected: CGFloat = layout.matRadius - layout.matPadding
            #expect(layout.photoRadius == expected)
            #expect(layout.photoRadius < layout.matRadius)
        }
    }

    @Test("Заголовок меню: 36 и 28 pt с трекингом −0,02 em")
    func theTitleKeepsItsTwoSizes() {
        // Кегль заголовка в `TypeScale` не заведён (крупнее `display` 34 там
        // ничего нет) — вопрос В7 дизайну. Пока числа живут в раскладке, и
        // сторожит их этот тест.
        #expect(MenuLayout.regular.titleSize == 36)
        #expect(MenuLayout.compact.titleSize == 28)
        let expectedTracking: CGFloat = 36 * -0.02
        #expect(MenuLayout.regular.titleTracking == expectedTracking)
        #expect(MenuLayout.regular.titleTracking < 0)
    }

    // MARK: «Продолжить партию»

    @Test("Продолжать нечего — ссылки нет")
    func nothingToContinue() {
        let target = ContinueTarget.resolve(isPlaying: false,
                                            hasVsComputer: false, hasHotSeat: false)
        #expect(target == .none)
        #expect(!target.isAvailable)
    }

    @Test("Одна незакрытая партия продолжается без вопросов")
    func aSingleSavedGameResumesStraightAway() {
        #expect(ContinueTarget.resolve(isPlaying: false,
                                       hasVsComputer: true, hasHotSeat: false) == .vsComputer)
        #expect(ContinueTarget.resolve(isPlaying: false,
                                       hasVsComputer: false, hasHotSeat: true) == .hotSeat)
    }

    @Test("Две незакрытые партии — спросить, какую продолжаем")
    func twoSavedGamesAskFirst() {
        // Молча выбрать одну значит потерять другую: сохранение против
        // компьютера одно, и новая партия его перезапишет.
        let target = ContinueTarget.resolve(isPlaying: false,
                                            hasVsComputer: true, hasHotSeat: true)
        #expect(target == .ask)
        #expect(target.isAvailable)
    }

    @Test("Идущая партия возвращается на поле и обгоняет любое сохранение")
    func aLiveMatchWinsOverEverySave() {
        // Партия, начатая в этом запуске, в `GameStore` ещё не лежит:
        // сохранение пишется только при уходе из приложения. Пока этого
        // случая не было, выход в меню делал идущую партию недоступной.
        #expect(ContinueTarget.resolve(isPlaying: true,
                                       hasVsComputer: false, hasHotSeat: false) == .resume)
        #expect(ContinueTarget.resolve(isPlaying: true,
                                       hasVsComputer: true, hasHotSeat: true) == .resume)
    }
}
