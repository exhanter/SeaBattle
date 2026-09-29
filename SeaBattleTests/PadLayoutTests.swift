//
//  PadLayoutTests.swift
//  SeaBattleTests
//
//  R2.6 — iPad. Проверяется арифметика стола: размер клетки по ориентации и
//  фазе, потолок из токенов и главное — что два поля помещаются на любом
//  iPad, от mini до 13". Ошибка здесь не видна компилятору: поле просто
//  уезжает под нижнюю линию на том устройстве, которого нет под рукой.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("iPad: стол и навигация")
struct PadLayoutTests {

    /// Экраны iPad в точках: mini, 11", 13" — вертикально. Полоса состояния
    /// 24, полоска «домой» 20.
    static let portraits: [CGSize] = [
        CGSize(width: 744, height: 1133),
        CGSize(width: 820, height: 1180),
        CGSize(width: 834, height: 1194),
        CGSize(width: 1032, height: 1376),
    ]

    private func table(_ size: CGSize) -> PadTableGeometry {
        PadTableGeometry(size: size, safeTop: 24, safeBottom: 20)
    }

    // MARK: Ориентация

    @Test("Ориентация — по пропорции области, а не по датчику")
    func orientationFollowsTheArea() {
        #expect(PadOrientation.of(CGSize(width: 834, height: 1194)) == .portrait)
        #expect(PadOrientation.of(CGSize(width: 1194, height: 834)) == .landscape)
        // Split View: горизонтальный iPad, но окно выше, чем шире.
        #expect(PadOrientation.of(CGSize(width: 694, height: 834)) == .portrait)
    }

    // MARK: Клетка

    @Test("iPad 11\": клетка 42 в обеих ориентациях (раунд 7)")
    func theEleveninchPadGetsTheTokenCell() {
        #expect(table(CGSize(width: 834, height: 1194)).cell == 42)
        #expect(table(CGSize(width: 1194, height: 834)).cell == 42)
        #expect(Geometry.Cell.iPadLandscape == Geometry.Cell.iPadPortrait)
    }

    @Test("Токен — потолок: большой iPad не раздувает клетку")
    func theTokenIsACeiling() {
        #expect(table(CGSize(width: 1032, height: 1376)).cell == Geometry.Cell.iPadPortrait)
        #expect(table(CGSize(width: 1376, height: 1032)).cell == Geometry.Cell.iPadLandscape)
    }

    @Test("iPad mini: клетка меньше токена, но не меньше минимума")
    func theMiniShrinksTheCell() {
        let mini = table(CGSize(width: 744, height: 1133))
        #expect(mini.cell < Geometry.Cell.iPadPortrait)
        #expect(mini.cell >= PadTableGeometry.minCell)
    }

    // MARK: Отступы

    @Test("Горизонтально три равных отступа: 86 · 86 · 86 на 1194")
    func landscapeMarginsAreEqual() {
        let g = table(CGSize(width: 1194, height: 834))
        #expect(g.sideMargin == g.middleMargin)
        #expect(2 * g.sideMargin + g.middleMargin + 2 * g.boardSide == 1194)
    }

    @Test("Нечётный остаток отступов отдаётся середине")
    func theRemainderGoesToTheMiddle() {
        // 1000 − 2 × 450 = 100: 33 · 34 · 33.
        let m = PadTableGeometry.margins(width: 1000, boardSide: 450)
        #expect(m.side == 33)
        #expect(m.middle == 34)
        // 101: 33 · 35 · 33.
        let n = PadTableGeometry.margins(width: 1001, boardSide: 450)
        #expect(n.side == 33)
        #expect(n.middle == 35)
    }

    // MARK: Всё помещается

    @Test("Вертикально: два поля и названия помещаются на любом iPad",
          arguments: PadLayoutTests.portraits)
    func portraitTableFits(_ size: CGSize) {
        let g = table(size)
        let used = g.top + PadTableGeometry.topPanelHeight + PadTableGeometry.topGap
            + 2 * (PadTableGeometry.titleBlock + g.boardSide) + PadTableGeometry.blockGap
            + g.bottom
        #expect(used <= size.height, "\(size): \(used)")
        // Поле не заходит под ленту справа (128 + зазор 14) и под квадраты.
        let side = (size.width - g.boardSide) / 2
        #expect(side >= PadTableGeometry.frame + Geometry.Inset.feedWidthPortrait
                    + PadTableGeometry.feedClearance, "\(size): \(side)")
    }

    @Test("Горизонтально: поля рядом, под своим полем помещаются лента и квадраты",
          arguments: PadLayoutTests.portraits)
    func landscapeTableFits(_ portrait: CGSize) {
        let size = CGSize(width: portrait.height, height: portrait.width)
        let g = table(size)
        #expect(g.sideMargin >= PadTableGeometry.frame, "\(size): \(g.sideMargin)")
        let under = max(PadTableGeometry.feedHeight, PadTableGeometry.tile)
        let height = g.top + PadTableGeometry.topPanelHeight + PadTableGeometry.topGap
            + PadTableGeometry.titleBlock + g.boardSide
            + PadTableGeometry.feedClearance + under + g.bottom
        #expect(height <= size.height, "\(size): \(height)")
    }

    @Test("Рамка 24 pt, но не под полосой состояния и не под полоской «домой»")
    func theFrameRespectsTheSystemBars() {
        let g = table(CGSize(width: 834, height: 1194))
        #expect(g.top == 24)
        #expect(g.bottom == 24)
        let tall = PadTableGeometry(size: CGSize(width: 834, height: 1194),
                                    safeTop: 32, safeBottom: 30)
        #expect(tall.top == 32)
        #expect(tall.bottom == 30)
    }

    // MARK: Меню

    @Test("Меню: плитки на 16 над нижним рядом, арт уходит под них на 40",
          arguments: PadLayoutTests.portraits)
    func theMenuZonesStackFromTheBottom(_ size: CGSize) {
        for s in [size, CGSize(width: size.height, height: size.width)] {
            let g = PadMenuGeometry(size: s, safeBottom: 20)
            #expect(g.bottomRowTop + Geometry.Inset.padTile + 24 == s.height)
            #expect(g.tilesTop + g.tilesHeight + Geometry.PadMenu.aboveBottomRow == g.bottomRowTop)
            #expect(g.artHeight == g.tilesTop + Geometry.PadMenu.artOverlap)
            // Название целиком на арте, под полосой состояния.
            #expect(g.titleTop >= 24, "\(s)")
        }
    }

    @Test("Меню 834 × 1194: арт 674, 1194 × 834: арт 554 — как в кадрах 22a / 22b")
    func theMenuArtMatchesTheMockups() {
        #expect(PadMenuGeometry(size: CGSize(width: 834, height: 1194), safeBottom: 20).artHeight == 674)
        #expect(PadMenuGeometry(size: CGSize(width: 1194, height: 834), safeBottom: 20).artHeight == 554)
    }

    // MARK: Квадраты

    @Test("Углы корней табов: свой угол занимает «Играть»")
    func theCornerTilesSwapTheCurrentTab() {
        #expect(PadCorners.tabs(on: .play) == (.statistics, .settings))
        #expect(PadCorners.tabs(on: .statistics) == (.play, .settings))
        #expect(PadCorners.tabs(on: .settings) == (.statistics, .play))
    }

    @Test("Все кнопки нижней линии — квадраты 104")
    func everyBottomButtonIsATile() {
        #expect(PadTileMetrics.side == 104)
        #expect(PadTableGeometry.tile == PadTileMetrics.side)
        #expect(Geometry.Nav.padDialog == 400)
    }

    @Test("Лента на iPad — три капсулы видно сразу")
    func theShotColumnShowsThreeShots() {
        #expect(ShotColumnMetrics.visible == 3)
        #expect(PadTableGeometry.feedHeight == ShotColumnMetrics.height)
    }

    @Test("Панель счёта iPad — числа кадра score21")
    func thePadScorePanelFollowsTheMockup() {
        #expect(BattleMetrics.pad.sideNumber == 22)
        #expect(BattleMetrics.pad.dot == 8)
        #expect(BattleMetrics.pad.dotGap == 4)
        // На iPhone зазор точек прежний.
        #expect(BattleMetrics.regular.dotGap == 3)
    }
}
