//
//  BoardCellTests.swift
//  SeaBattleTests
//
//  R1.3 — клетка поля. Вид сверяется превью с блоком 3a макетов, а тестом
//  проверяется единственное правило, которое можно нарушить незаметно: на чьём
//  поле попадание показывается пробоиной, а на чьём — огнём на своём корпусе.
//  Ошибись здесь — и игрок увидит на своём поле аккуратную дырку в воде вместо
//  горящего корабля, причём сборка будет зелёной.
//

import Testing
@testable import SeaBattle

@Suite("Клетка поля")
struct BoardCellTests {

    @Test("Попадание по своему полю — огонь на корпусе, по чужому — пробоина")
    func aHitLooksDifferentOnEachSide() {
        #expect(BoardCellState.forDisplay(.hit, on: .you) == .hitMine)
        #expect(BoardCellState.forDisplay(.hit, on: .foe) == .hit)
    }

    @Test("Остальные состояния от стороны не зависят")
    func everyOtherStateIsTheSameOnBothSides() {
        for state in [CellState.water, .miss, .ship, .sunk] {
            #expect(BoardCellState.forDisplay(state, on: .you)
                    == BoardCellState.forDisplay(state, on: .foe),
                    "\(state) не должно зависеть от стороны")
        }
    }

    @Test("Каждое состояние ядра переводится во что-то осмысленное")
    func everyCoreStateHasADisplayState() {
        // Ядро знает пять состояний, отрисовка — семь. Шестое — огонь на своём
        // корпусе, седьмое (R2.2) — розовый корабль в запрещённой позиции: оно
        // существует, только пока корабль ставят, и из ядра не приходит никогда.
        // Если в ядре появится новое состояние, компилятор заставит дописать
        // перевод, а этот тест — проверить, во что именно.
        let expected: [CellState: BoardCellState] = [
            .water: .water, .miss: .miss, .ship: .ship, .hit: .hit, .sunk: .sunk,
        ]
        for state in CellState.allCases {
            #expect(BoardCellState.forDisplay(state, on: .foe) == expected[state])
            #expect(BoardCellState.forDisplay(state, on: .foe) != .shipDenied)
        }
        #expect(CellState.allCases.count == 5)
        #expect(BoardCellState.allCases.count == 7)
    }

    @Test("Радиус клетки считается от размера во всех применяемых размерах")
    func theRadiusFollowsEverySizeInUse() {
        // Клетка рисуется одним кодом на всех устройствах, поэтому проверяем,
        // что радиус нигде не вырождается: ни в квадрат, ни в круг.
        for size in [Geometry.Cell.iPhoneSmallCoords, Geometry.Cell.iPhoneSmall,
                     Geometry.Cell.iPhone, Geometry.Cell.iPadTable,
                     Geometry.Cell.iPadPortrait, Geometry.Cell.iPadLandscape,
                     Geometry.Cell.iPadPlacement] {
            let radius = Geometry.cellRadius(for: size)
            #expect(radius >= 4)
            #expect(radius < size / 2)
        }
    }
}
