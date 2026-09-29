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

    private func table(_ size: CGSize, _ phase: PadTableGeometry.Phase) -> PadTableGeometry {
        PadTableGeometry(size: size, safeTop: 24, safeBottom: 20, phase: phase)
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

    @Test("iPad 11\": клетки из токенов — 42 вертикально, 44 горизонтально")
    func theEleveninchPadGetsTheTokenCells() {
        #expect(table(CGSize(width: 834, height: 1194), .battle).cell == Geometry.Cell.iPadPortrait)
        #expect(table(CGSize(width: 1194, height: 834), .battle).cell == Geometry.Cell.iPadLandscape)
    }

    @Test("Горизонтально клетка одна до старта и в бою — поля не прыгают по «Начать»")
    func landscapeCellDoesNotJumpOnStart() {
        for portrait in Self.portraits {
            let landscape = CGSize(width: portrait.height, height: portrait.width)
            #expect(table(landscape, .placement).cell == table(landscape, .battle).cell,
                    "\(landscape)")
        }
    }

    @Test("Токен — потолок: большой iPad не раздувает клетку")
    func theTokenIsACeiling() {
        let big = CGSize(width: 1032, height: 1376)
        #expect(table(big, .battle).cell == Geometry.Cell.iPadPortrait)
        #expect(table(big, .placement).cell == Geometry.Cell.iPadTable)
        let wide = CGSize(width: 1376, height: 1032)
        #expect(table(wide, .battle).cell == Geometry.Cell.iPadLandscape)
    }

    @Test("iPad mini: клетка меньше токена, но не меньше минимума")
    func theMiniShrinksTheCell() {
        let mini = table(CGSize(width: 744, height: 1133), .battle)
        #expect(mini.cell < Geometry.Cell.iPadPortrait)
        #expect(mini.cell >= PadTableGeometry.minCell)
    }

    // MARK: Всё помещается

    @Test("Вертикально: два поля, названия и нижний ряд помещаются на любом iPad",
          arguments: PadLayoutTests.portraits)
    func portraitTableFits(_ size: CGSize) {
        for phase in [PadTableGeometry.Phase.battle, .placement] {
            let g = table(size, phase)
            var used = g.top + PadTableGeometry.topPanelHeight + PadTableGeometry.topGap
                + 2 * (PadTableGeometry.titleBlock + g.boardSide) + PadTableGeometry.blockGap
                + g.bottom
            if phase == .placement {
                used += PadTableGeometry.bottomRowHeight + PadTableGeometry.blockGap
            }
            #expect(used <= size.height, "\(size) \(phase): \(used)")
        }
        // В бою поле не заходит под ленту справа и под «Меню» с подсказкой.
        let g = table(size, .battle)
        let side = (size.width - g.boardSide) / 2
        #expect(side >= PadTableGeometry.frame + Geometry.Inset.feedWidthPortrait,
                "\(size): \(side)")
    }

    @Test("Горизонтально: поля рядом, под своим полем помещается лента",
          arguments: PadLayoutTests.portraits)
    func landscapeTableFits(_ portrait: CGSize) {
        let size = CGSize(width: portrait.height, height: portrait.width)
        let g = table(size, .battle)
        let width = 2 * PadTableGeometry.frame + 2 * g.boardSide + Geometry.Inset.boardGapPad
        #expect(width <= size.width, "\(size): \(width)")
        let height = g.top + PadTableGeometry.topPanelHeight + PadTableGeometry.topGap
            + PadTableGeometry.titleBlock + g.boardSide
            + PadTableGeometry.feedClearance + PadTableGeometry.feedHeight + g.bottom
        #expect(height <= size.height, "\(size): \(height)")
    }

    @Test("Рамка 24 pt, но не под полосой состояния и не под полоской «домой»")
    func theFrameRespectsTheSystemBars() {
        let g = PadTableGeometry(size: CGSize(width: 834, height: 1194),
                                 safeTop: 24, safeBottom: 20, phase: .battle)
        #expect(g.top == 24)
        #expect(g.bottom == 24)
        let tall = PadTableGeometry(size: CGSize(width: 834, height: 1194),
                                    safeTop: 32, safeBottom: 30, phase: .battle)
        #expect(tall.top == 32)
        #expect(tall.bottom == 30)
    }

    // MARK: Компоненты

    @Test("Лента на iPad — три капсулы видно сразу")
    func theShotColumnShowsThreeShots() {
        #expect(ShotColumnMetrics.visible == 3)
        #expect(PadTableGeometry.feedHeight == ShotColumnMetrics.height)
    }

    @Test("Кант рельса — по правой кромке, она смотрит в море")
    func theRailWoodFacesTheSea() {
        #expect(WoodEdge.trailing.alignment == .trailing)
        #expect(WoodEdge.trailing.isVertical)
        #expect(!WoodEdge.top.isVertical)
    }

    @Test("Панель счёта iPad — числа кадра score11")
    func thePadScorePanelFollowsTheMockup() {
        #expect(BattleMetrics.pad.sideNumber == 22)
        #expect(BattleMetrics.pad.dot == 8)
        #expect(BattleMetrics.pad.dotGap == 4)
        // На iPhone зазор точек прежний.
        #expect(BattleMetrics.regular.dotGap == 3)
    }

    @Test("Подсказка: квадрат в ширину рельса вертикально, высота панели горизонтально")
    func theHintPlateMatchesTheNavigation() {
        #expect(Geometry.Inset.railWidth == 104)
        #expect(PadNavMetrics.barHeight == Geometry.Inset.hintHeightLandscape)
        #expect(PadTableGeometry.bottomRowHeight == PadNavMetrics.barHeight)
    }
}
