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
@MainActor
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

    @Test("Таб-бар: 68 pt на большом экране, 56 на малом")
    func theTabBarFollowsTheMockup() {
        #expect(Geometry.SizeClass.regular.tabHeight == 68)
        #expect(Geometry.SizeClass.regular.tabRadius == Geometry.Radius.panelLarge)
        #expect(Geometry.SizeClass.compact.tabHeight == 56)
        #expect(TabBarMetrics.inactiveOpacity == 0.62)
        // 56 pt — не цель нажатия: цели это сами табы, каждый шире и выше 44 pt
        // (спека 3.3 говорит об этом прямо, чтобы число не «исправили»).
        #expect(Geometry.SizeClass.compact.tabHeight >= Geometry.Hit.minTarget)
    }

    @Test("Таб-бар и меню переключаются одной границей 390 pt")
    func oneBreakpointForTheWholeScreen() {
        // Две границы дали бы малый таб-бар под большим меню — и наоборот; на
        // одном устройстве из семи это выглядело бы случайным. Теперь размер
        // один на весь экран и приходит из пакета.
        #expect(Geometry.SizeClass.compactBreakpoint == 390)
        #expect(!Geometry.SizeClass.forWidth(393).isCompact)
        #expect(!Geometry.SizeClass.forWidth(430).isCompact)
        #expect(Geometry.SizeClass.forWidth(375).isCompact)
        #expect(Geometry.SizeClass.forWidth(320).isCompact)
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
        #expect(Geometry.SizeClass.regular.photo == 252)
        #expect(Geometry.SizeClass.compact.photo == 170)
    }

    @Test("Внутренний радиус мата меньше внешнего ровно на толщину мата")
    func theMatCornersNest() {
        // Иначе угол фотографии либо вылезает за мат, либо оставляет просвет —
        // на скриншоте это пара точек, глазами не ловится. Оба радиуса
        // переписаны из кадров как отдельные числа, поэтому проверка заодно
        // говорит, что кадры согласованы и переписаны верно.
        for size in [Geometry.SizeClass.regular, .compact] {
            let expected: CGFloat = size.photoRadius - size.mat
            #expect(size.photoInnerRadius == expected)
            #expect(size.photoInnerRadius < size.photoRadius)
        }
    }

    @Test("Заголовок игры: трекинг отрицательный на обоих размерах")
    func theGameTitleIsTracked() {
        // Кегль и трекинг заголовка пришли токенами в раунде 3
        // (`TypeScale.gameTitle`), `display` из пакета удалён. Трекинг −0,02 em
        // легко потерять при переносе, а без него заголовок выглядит шире.
        #expect(TypeScale.gameTitleTracking(compact: false) == -0.72)
        #expect(TypeScale.gameTitleTracking(compact: true) == -0.56)
        #expect(TypeScale.screenTitleTracking < 0)
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

    // MARK: Шаг выбора уровня

    @Test("По умолчанию уровень спрашивается перед партией")
    func theLevelIsAskedByDefault() {
        let step = LevelStep.resolve(remembered: .medium,
                                     askBeforeMatch: true, isPremium: false)
        #expect(step == .ask(selected: .medium))
    }

    @Test("Тумблер выключен — партия стартует сразу на запомненном уровне")
    func theLevelStepCanBeSwitchedOff() {
        let step = LevelStep.resolve(remembered: .easy,
                                     askBeforeMatch: false, isPremium: false)
        #expect(step == .start(.easy))
    }

    @Test("Запомнен «Эксперт» без Pro — экран показывается даже при выключённом тумблере")
    func expertWithoutProAlwaysAsks() {
        // Три правила, и это — исключение, которое сильнее тумблера (спека 4.3).
        // Молча понизить уровень нельзя: игрок решит, что компьютер поглупел.
        let off = LevelStep.resolve(remembered: .expert,
                                    askBeforeMatch: false, isPremium: false)
        #expect(off == .ask(selected: .hard))
        let on = LevelStep.resolve(remembered: .expert,
                                   askBeforeMatch: true, isPremium: false)
        #expect(on == .ask(selected: .hard))
        // С Pro «Эксперт» остаётся выбранным и тумблер снова главный.
        #expect(LevelStep.resolve(remembered: .expert,
                                  askBeforeMatch: false, isPremium: true) == .start(.expert))
        #expect(LevelStep.resolve(remembered: .expert,
                                  askBeforeMatch: true, isPremium: true) == .ask(selected: .expert))
    }

    @Test("Четыре уровня, замок только у «Эксперта»")
    func onlyTheExpertIsLocked() {
        #expect(LevelChoice.all.map(\.level) == AppState.DifficultyLevel.allCases)
        #expect(LevelChoice.all.count == 4)
        let locked = LevelChoice.all.filter { $0.isLocked(isPremium: false) }.map(\.level)
        #expect(locked == [.expert])
        #expect(LevelChoice.all.filter { $0.isLocked(isPremium: true) }.isEmpty)
        // Подмена закрытого уровня — бесплатная, иначе экран открывался бы на
        // строке с замком.
        #expect(!AppState.DifficultyLevel.freeFallback.isPremium)
    }

    @Test("Шкала уровня растёт от «Легко» к «Эксперту» и у «Эксперта» полная")
    func levelBarsGrowWithStrength() {
        // Значок уровня — шкала силы (07.10): капсула в бою, список и
        // статистика берут деления отсюда, и порядок должен читаться сам.
        let values = LevelChoice.all.map(\.iconValue)
        #expect(values == values.sorted())
        #expect(Set(values).count == values.count)
        #expect(LevelChoice.iconValue(for: .expert) == 1)
        #expect(LevelChoice.iconValue(for: .easy) > 0)
    }

    @Test("Капсула уровня не выше строки подписи поля")
    func theLevelChipDoesNotPushTheLayout() {
        // Спека 4.5 обещает, что от капсулы раскладка боя не меняется. Держится
        // это на одном: капсула не выше строки, в которой стоит.
        #expect(LevelChip.Metrics.regular.height == 22)
        #expect(LevelChip.Metrics.compact.height == 20)
        // Радиус — половина высоты: капсула, а не плашка со скруглением.
        #expect(LevelChip.Metrics.regular.radius == 11)
        #expect(LevelChip.Metrics.compact.height < LevelChip.Metrics.regular.height)
        #expect(LevelChip.gap(.compact) < LevelChip.gap(.regular))
    }

    @Test("Уровень лежит в тех же числах, что и до редизайна")
    func theStoredLevelKeepsItsLegacyNumbers() {
        // Порядок не по возрастанию сложности, и менять его нельзя: у всех, у
        // кого игра уже стоит, настройка сбросится на чужой уровень.
        #expect(AppState.DifficultyLevel.hard.storedValue == 0)
        #expect(AppState.DifficultyLevel.medium.storedValue == 1)
        #expect(AppState.DifficultyLevel.easy.storedValue == 2)
        #expect(AppState.DifficultyLevel.expert.storedValue == 3)
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

    @Test("Экран уровня: тумблер обводки уходит, когда не помещается, и возвращается без дёрганья")
    func markWaterTogglesByRoom() {
        // Показан, всё влезает — остаётся; на 1 pt больше — уходит.
        #expect(LevelScreen.markWaterFits(isShown: true, content: 600, slot: 58, viewport: 600))
        #expect(!LevelScreen.markWaterFits(isShown: true, content: 601, slot: 58, viewport: 600))
        // Скрыт: возвращается, только если влезет вместе со своим местом.
        #expect(!LevelScreen.markWaterFits(isShown: false, content: 543, slot: 58, viewport: 600))
        #expect(LevelScreen.markWaterFits(isShown: false, content: 542, slot: 58, viewport: 600))
        // Скрыли при 601 → без него 543 → снова не влезает: решение устойчиво.
        #expect(!LevelScreen.markWaterFits(isShown: false, content: 601 - 58, slot: 58, viewport: 600))
    }
}
