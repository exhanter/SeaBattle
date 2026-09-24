//
//  BoardViewTests.swift
//  SeaBattleTests
//
//  R1.4 — поле. Проверяется арифметика обвязки и буквы столбцов: и то и другое
//  легко разъезжается незаметно. Если подложка окажется на пиксель уже сетки,
//  сборка останется зелёной, а поле будет выглядеть кривым на одном устройстве
//  из семи.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("Поле")
struct BoardViewTests {

    @Test("Сторона поля складывается из клеток, зазоров и отступа")
    func theBoardSideAddsUp() {
        let m = BoardMetrics(cell: 32, gap: 3)
        // 10 клеток по 32 плюс 9 зазоров по 3 = 347 — число из спеки,
        // плюс отступ подложки с двух сторон.
        let expectedGrid: CGFloat = 347
        let expectedBoard: CGFloat = 347 + Geometry.boardInset * 2
        #expect(m.gridSide == expectedGrid)
        #expect(m.boardSide == expectedBoard)
    }

    @Test("Радиус подложки продолжает скругление угловой клетки")
    func theBackingRadiusContinuesTheCorner() {
        for cell in [Geometry.Cell.iPhoneSmallCoords, Geometry.Cell.iPhone,
                     Geometry.Cell.iPadPortrait, Geometry.Cell.iPadPlacement] {
            let m = BoardMetrics(cell: cell)
            #expect(m.radius == Geometry.cellRadius(for: cell) + Geometry.boardInset)
        }
    }

    @Test("Без координат поле не тратит на них ни точки")
    func withoutCoordinatesNothingIsReserved() {
        let m = BoardMetrics(cell: 32, gap: 3)
        #expect(m.digitsWidth == 0)
        #expect(m.lettersHeight == 0)
        #expect(m.axisGap == 0)
        #expect(m.totalSize == CGSize(width: m.boardSide, height: m.boardSide))
    }

    @Test("Координаты занимают место слева и сверху, но поле не сжимают")
    func coordinatesTakeRoomOutsideTheBoard() {
        let plain = BoardMetrics(cell: 30, gap: 3)
        let coords = BoardMetrics(cell: 30, gap: 3, coordinates: true)
        // Клетка в игре на бумаге уменьшена заранее (30 вместо 32), поэтому
        // сама подложка при включении координат не меняется — растёт только
        // общий размер.
        #expect(coords.boardSide == plain.boardSide)
        #expect(coords.totalSize.width == plain.boardSide + 16 + 3)
        #expect(coords.totalSize.height == plain.boardSide + 14 + 3)
    }

    @Test("Поле с координатами влезает в ширину iPhone SE")
    func thePaperBoardFitsTheSmallestPhone() {
        // 375 pt минус боковые отступы 12 × 2 — то, ради чего в игре на бумаге
        // клетка уменьшена до 28.
        let available: CGFloat = 375 - Geometry.Inset.phoneSide * 2
        let m = BoardMetrics(cell: Geometry.Cell.iPhoneSmallCoords, gap: Geometry.Cell.gapPhone,
                             coordinates: true)
        #expect(m.totalSize.width <= available)
    }

    @Test("Буквы столбцов: русские без Ё и Й, латинские A–J")
    func theColumnLettersAreTenAndSkipTheAwkwardOnes() {
        #expect(BoardAlphabet.cyrillic.letters.count == 10)
        #expect(BoardAlphabet.latin.letters.count == 10)
        #expect(BoardAlphabet.cyrillic.letters.first == "А")
        #expect(BoardAlphabet.cyrillic.letters.last == "К")
        #expect(BoardAlphabet.latin.letters == ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"])
        // Ё и Й пропущены: их легко перепутать на слух и в наборе.
        #expect(BoardAlphabet.cyrillic.letters.contains("Ё") == false)
        #expect(BoardAlphabet.cyrillic.letters.contains("Й") == false)
    }

    @Test("Русский интерфейс получает русские буквы, остальные — латинские")
    func theAlphabetFollowsTheInterfaceLanguage() {
        #expect(BoardAlphabet.forLanguage("ru") == .cyrillic)
        #expect(BoardAlphabet.forLanguage("en") == .latin)
        #expect(BoardAlphabet.forLanguage("nl") == .latin)
        #expect(BoardAlphabet.forLanguage(nil) == .latin)
    }
}

extension BoardAlphabet: Equatable {}
