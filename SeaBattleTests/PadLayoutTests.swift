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

    @Test("iPad 11\": клетка растёт от места, а не стоит на токене (10.10)")
    func theEleveninchPadGrowsTheCellToFit() {
        // Вертикально место отдают воздуху под полем противника: клетка 39.
        #expect(table(CGSize(width: 834, height: 1194)).cell == 39)
        // Горизонтально высоты больше — клетка крупнее (41: с 13.10 поля по
        // центру между панелью и квадратами, лента висит в нижнем зазоре).
        #expect(table(CGSize(width: 1194, height: 834)).cell == 41)
    }

    @Test("Потолок — maxCell: 13\" горизонтально упирается в него")
    func theCeilingIsMaxCell() {
        #expect(table(CGSize(width: 1376, height: 1032)).cell == PadTableGeometry.maxCell)
        // 13" вертикально: поля крупнее, чем на 11".
        #expect(table(CGSize(width: 1032, height: 1376)).cell > table(CGSize(width: 834, height: 1194)).cell)
    }

    @Test("iPad mini: клетка меньше токена, но не меньше минимума")
    func theMiniShrinksTheCell() {
        let mini = table(CGSize(width: 744, height: 1133))
        #expect(mini.cell < Geometry.Cell.iPadPortrait)
        #expect(mini.cell >= PadTableGeometry.minCell)
    }

    // MARK: Отступы

    @Test("Горизонтально три равных отступа, остаток — середине")
    func landscapeMarginsAreEqual() {
        let g = table(CGSize(width: 1194, height: 834))
        #expect(g.middleMargin >= g.sideMargin && g.middleMargin <= g.sideMargin + 2)
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

    @Test("Вертикально: два поля, названия и воздух под полем противника помещаются на любом iPad",
          arguments: PadLayoutTests.portraits)
    func portraitTableFits(_ size: CGSize) {
        let g = table(size)
        let used = g.top + PadTableGeometry.topPanelHeight
            + 2 * (PadTableGeometry.titleBlock + g.boardSide) + 3 * PadTableGeometry.breathing
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
        // Поля по центру между панелью и квадратами, зазоры равны; лента
        // висит в нижнем и не касается поля (зазор 14).
        let gap = PadTableGeometry.landscapeGap(coordinates: false)
        let height = g.top + PadTableGeometry.topPanelHeight + gap
            + PadTableGeometry.titleBlock + g.boardSide
            + gap + PadTableGeometry.tile + g.bottom
        #expect(height <= size.height, "\(size): \(height)")
        #expect(gap + PadTableGeometry.tile
                    >= PadTableGeometry.feedHeight + PadTableGeometry.feedClearance)
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

    @Test("Меню: плитки на 16 над нижним рядом, корабль арта — под часами и над названием или плитками",
          arguments: PadLayoutTests.portraits)
    func theMenuZonesStackFromTheBottom(_ size: CGSize) {
        for s in [size, CGSize(width: size.height, height: size.width)] {
            let g = PadMenuGeometry(size: s, safeTop: 24, safeBottom: 20)
            #expect(g.bottomRowTop + Geometry.Inset.padTile + 24 == s.height)
            #expect(g.tilesTop + g.tilesHeight + Geometry.PadMenu.aboveBottomRow == g.bottomRowTop)
            #expect(g.titleTop >= 24, "\(s)")
            #expect(g.shipBox.minY == 24 + Geometry.PadMenu.shipBelowStatusBar)
            #expect(g.shipBox.maxX <= s.width - Geometry.Inset.padFrame)
            if g.orientation == .portrait {
                // Вертикально название — под кораблём.
                #expect(g.shipBox.maxY == g.titleTop, "\(s)")
            } else {
                // Горизонтально корпус — над плитками, название — слева от него.
                #expect(g.shipBox.maxY < g.tilesTop, "\(s)")
                #expect(g.shipBox.minX > Geometry.Inset.padFrame * 2, "\(s)")
            }
        }
    }

    @Test("Корабль арта целиком в своей рамке, картинка закрывает экран")
    func theShipFitsItsBox() {
        for size in PadLayoutTests.portraits {
            for s in [size, CGSize(width: size.height, height: size.width)] {
                let g = PadMenuGeometry(size: s, safeTop: 24, safeBottom: 20)
                let f = PadShipArt.imageFrame(shipBox: g.shipBox, canvas: s)
                let ship = PadShipArt.ship
                // Нос, корма и острие ракеты — в рамке.
                #expect(f.minX + ship.minX * f.width >= g.shipBox.minX - 0.5, "\(s)")
                #expect(f.minX + ship.maxX * f.width <= g.shipBox.maxX + 0.5, "\(s)")
                #expect(f.minY + ship.minY * f.height >= g.shipBox.minY - 0.5, "\(s)")
                // Над картинкой и по бокам пустоты нет; горизонтально вода
                // доходит до низа экрана.
                #expect(f.minX <= 0 && f.maxX >= s.width && f.minY <= 0, "\(s)")
                if g.orientation == .landscape {
                    #expect(f.maxY >= s.height, "\(s)")
                }
            }
        }
    }

    // MARK: Квадраты

    @Test("Углы корней табов: свой угол занимает «Главная»")
    func theCornerTilesSwapTheCurrentTab() {
        #expect(PadCorners.tabs(on: .play) == (.statistics, .settings))
        #expect(PadCorners.tabs(on: .statistics) == (.play, .settings))
        #expect(PadCorners.tabs(on: .settings) == (.statistics, .play))
    }

    @Test("Все кнопки нижней линии — квадраты одного размера")
    func everyBottomButtonIsATile() {
        #expect(PadTableGeometry.tile == PadTileMetrics.side)
        #expect(Geometry.Inset.padTile == PadTileMetrics.side)
    }

    @Test("Лента на iPad — три капсулы видно сразу")
    func theShotColumnShowsThreeShots() {
        #expect(ShotColumnMetrics.visible == 3)
        #expect(PadTableGeometry.feedHeight == ShotColumnMetrics.height)
    }

    // MARK: Игра на бумаге (раунд 8)

    @Test("Стол игры на бумаге: два поля с координатами помещаются вертикально",
          arguments: PadLayoutTests.portraits)
    func thePaperTableFitsCoordinates(_ size: CGSize) {
        let g = PadTableGeometry(size: size, safeTop: 24, safeBottom: 20, coordinates: true)
        let letters = g.metrics.lettersHeight + g.metrics.axisGap
        let used = g.top + PadTableGeometry.topPanelHeight
            + 2 * (PadTableGeometry.titleBlock + letters + g.boardSide) + 3 * PadTableGeometry.breathing
            + g.bottom
        #expect(used <= size.height, "\(size): \(used)")
    }

    @Test("Стол игры на бумаге: цифры висят в отступе слева от сетки")
    func thePaperTableHangsTheDigits() {
        for size in [CGSize(width: 834, height: 1194), CGSize(width: 1194, height: 834)] {
            let g = PadTableGeometry(size: size, safeTop: 24, safeBottom: 20, coordinates: true)
            #expect(g.metrics.showsCoordinates)
            // Цифры висят в отступе слева от сетки — он шире столбика цифр.
            if g.orientation == .landscape { #expect(g.sideMargin > g.axisWidth) }
        }
    }

    @Test("Без координат у стола нет столбика цифр")
    func theBattleTableHasNoAxis() {
        let g = PadTableGeometry(size: CGSize(width: 1194, height: 834), coordinates: false)
        #expect(g.axisWidth == 0)
    }
}
