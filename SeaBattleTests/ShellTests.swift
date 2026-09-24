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

    @Test("Таб-бар: 66 pt, радиус большой панели, цель нажатия не меньше 44")
    func theTabBarFollowsTheMockup() {
        #expect(TabBarMetrics.height == 66)
        #expect(TabBarMetrics.radius == Geometry.Radius.panelLarge)
        #expect(TabBarMetrics.height >= Geometry.Hit.minTarget)
        #expect(TabBarMetrics.inactiveOpacity == 0.6)
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
        #expect(MenuMetrics.heroSide(forWidth: 393) == 252)
        #expect(MenuMetrics.heroSide(forWidth: 430) == 252)
        #expect(MenuMetrics.heroSide(forWidth: 375) == 170)
        #expect(MenuMetrics.heroSide(forWidth: 320) == 170)
    }

    @Test("Внутренний радиус мата меньше внешнего ровно на толщину мата")
    func theMatCornersNest() {
        // Иначе угол фотографии либо вылезает за мат, либо оставляет просвет —
        // на скриншоте это пара точек, глазами не ловится.
        let expected: CGFloat = MenuMetrics.matRadius - MenuMetrics.matPadding
        #expect(MenuMetrics.photoRadius == expected)
        #expect(MenuMetrics.photoRadius < MenuMetrics.matRadius)
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
