//
//  ArrangementTests.swift
//  SeaBattleTests
//
//  R2.2 — расстановка. Проверяется поведение, которое легко сломать незаметно:
//  корабль, отпущенный в запрете, должен **остаться** там (иначе ошибка
//  спрячется сама), «Готово» должно держаться на конфликтах, а дрожание клетки
//  не должно меняться между перерисовками.
//

import Testing
import SwiftUI
@testable import SeaBattle

@Suite("Расстановка")
struct ArrangementTests {

    private func editorWithCanonicalFleet() -> FleetEditor {
        FleetEditor(ships: FleetLayout.canonicalLayout())
    }

    // MARK: Режимы

    @Test("Экран открывается с готовым флотом и без режима изменения")
    func itOpensReady() {
        let editor = editorWithCanonicalFleet()
        #expect(editor.ships.count == FleetLayout.shipCount)
        #expect(!editor.isEditing)
        #expect(editor.canFinish)
        #expect(editor.draggingID == nil)
    }

    @Test("Случайная расстановка на старте законна")
    func theDefaultLayoutIsLegal() {
        // Экран открывается «от готового поля», и это поле не должно оказаться
        // с ошибкой: иначе «Старт» будет погашен сразу при входе.
        for _ in 0..<20 {
            let editor = FleetEditor()
            #expect(!editor.hasConflicts)
            #expect(FleetLayout.isValid(editor.ships))
        }
    }

    @Test("«Перемешать» даёт другую законную расстановку и сбрасывает захват")
    func shuffleKeepsTheFleetLegal() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let id = editor.ships[0].id
        editor.beginDragging(id)
        editor.shuffle()
        #expect(editor.draggingID == nil)
        #expect(FleetLayout.isValid(editor.ships))
        // Режим изменения перемешивание не выключает: это единственный выход из
        // положения, которое игрок не хочет распутывать руками.
        #expect(editor.isEditing)
    }

    @Test("Вне режима изменения корабль не двигается и не поворачивается")
    func nothingMovesOutsideEditing() {
        var editor = editorWithCanonicalFleet()
        let before = editor.ships
        let id = editor.ships[0].id
        editor.beginDragging(id)
        editor.dragBy(columns: 3, rows: 3)
        editor.rotate(id)
        #expect(editor.ships == before)
        #expect(editor.draggingID == nil)
    }

    // MARK: Перемещение

    @Test("Корабль смещается ровно на столько клеток, на сколько ушёл палец")
    func draggingMovesByCells() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let ship = editor.ships.first { $0.length == 1 }!
        editor.beginDragging(ship.id)
        editor.dragBy(columns: 1, rows: 2)
        #expect(editor.ship(id: ship.id)?.origin
                == Coordinate(row: ship.origin.row + 2, column: ship.origin.column + 1))
    }

    @Test("Смещение считается от места взятия, а не накапливается")
    func draggingIsNotCumulative() {
        // Жест присылает полное смещение на каждом событии. Если применять его
        // к текущему месту, корабль уедет в несколько раз дальше пальца.
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let ship = editor.ships.first { $0.length == 1 }!
        editor.beginDragging(ship.id)
        editor.dragBy(columns: 1, rows: 0)
        editor.dragBy(columns: 2, rows: 0)
        editor.dragBy(columns: 3, rows: 0)
        #expect(editor.ship(id: ship.id)?.origin.column == ship.origin.column + 3)
    }

    @Test("Корабль не уходит за край поля")
    func shipsStayOnTheBoard() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let ship = editor.ships.first { $0.length == 4 }!
        editor.beginDragging(ship.id)
        editor.dragBy(columns: 50, rows: 50)
        let moved = editor.ship(id: ship.id)!
        #expect(moved.isOnBoard)
        // Четырёхпалубный горизонтальный дальше седьмого столбца не встанет.
        #expect(moved.origin.column == Board.size - 3)
        #expect(moved.origin.row == Board.size)
    }

    @Test("Отпущенный в запрете корабль остаётся там же и гасит «Готово»")
    func anIllegalDropStays() {
        // Спека 4.4: возврат на прежнее место скрывал бы ошибку, а розовый
        // корабль и погашенное «Готово» заставляют переставить.
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let ship = editor.ships.first { $0.length == 2 }!
        editor.beginDragging(ship.id)
        editor.move(ship.id, to: Coordinate(row: 2, column: 2))
        editor.endDragging()

        #expect(editor.ship(id: ship.id)?.origin == Coordinate(row: 2, column: 2))
        #expect(editor.hasConflicts)
        #expect(!editor.canFinish)
        #expect(editor.conflicts.contains(ship.id))
        // Не только он: сосед, с которым он столкнулся, тоже розовый.
        #expect(editor.conflicts.count > 1)
    }

    @Test("«Готово» не закрывает режим, пока на поле ошибка")
    func doneIsBlockedWhileIllegal() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let ship = editor.ships.first { $0.length == 2 }!
        editor.move(ship.id, to: Coordinate(row: 2, column: 2))

        // Изменяющий метод нельзя звать внутри `#expect`: в макросе значение
        // становится неизменяемым.
        let blocked = editor.finishEditing()
        #expect(blocked == false)
        #expect(editor.isEditing)

        editor.shuffle()
        let finished = editor.finishEditing()
        #expect(finished)
        #expect(!editor.isEditing)
    }

    @Test("Пока корабль в руке, кнопки погашены")
    func actionsAreOffWhileDragging() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        #expect(editor.actionsEnabled)
        editor.beginDragging(editor.ships[0].id)
        #expect(!editor.actionsEnabled)
        editor.endDragging()
        #expect(editor.actionsEnabled)
    }

    // MARK: Поворот

    @Test("Поворот меняет ориентацию и оставляет корабль на поле")
    func rotationKeepsTheShipOnBoard() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        // Четырёхпалубный в первой строке: поворот вниз влезает, потому что
        // вращение идёт вокруг середины и корабль не свисает за край.
        let ship = editor.ships.first { $0.length == 4 }!
        editor.rotate(ship.id)
        let rotated = editor.ship(id: ship.id)!
        #expect(rotated.orientation == .vertical)
        #expect(rotated.isOnBoard)
    }

    @Test("Поворот у нижнего края не выносит корабль за поле")
    func rotationAtTheEdgeIsClamped() {
        var editor = editorWithCanonicalFleet()
        editor.beginEditing()
        let ship = editor.ships.first { $0.length == 4 }!
        editor.beginDragging(ship.id)
        editor.dragBy(columns: 0, rows: 50)   // в самый низ
        editor.endDragging()
        editor.rotate(ship.id)
        let rotated = editor.ship(id: ship.id)!
        #expect(rotated.orientation == .vertical)
        #expect(rotated.isOnBoard, "корабль свесился с поля после поворота")
    }

    @Test("Корабль находится по клетке, за которую его берут")
    func shipsAreFoundByCell() {
        let editor = editorWithCanonicalFleet()
        let ship = editor.ships[0]
        for cell in ship.cells {
            #expect(editor.ship(at: cell)?.id == ship.id)
        }
        // Пустая вода не отдаёт корабль: иначе тянуть можно было бы за что попало.
        #expect(editor.ship(at: Coordinate(row: 10, column: 10)) == nil)
    }

    // MARK: Дрожание

    @Test("Дрожание клетки не меняется между перерисовками")
    func theJiggleIsStablePerCell() {
        // Если брать период из генератора случайных чисел, на каждом обновлении
        // экрана анимация перезапустится с новой фазой и поле будет дёргаться
        // вместо того, чтобы дрожать.
        let cell = Coordinate(row: 4, column: 7)
        #expect(JiggleSpec.forCell(cell) == JiggleSpec.forCell(cell))
    }

    @Test("Период и фаза дрожания — из чисел спеки")
    func theJiggleFollowsTheSpec() {
        #expect(JiggleSpec.periods.count == 4)
        #expect(JiggleSpec.phases.count == 9)
        #expect(JiggleSpec.periods.first == Motion.jiggleRange.lowerBound)
        // Четыре значения с шагом 0,035 от 0,40 не должны выйти за 0,51.
        #expect(JiggleSpec.periods.last! <= Motion.jiggleRange.upperBound)
        #expect(JiggleSpec.phases.last! == Motion.jigglePhase.upperBound)
        #expect(JiggleSpec.forCell(Coordinate(row: 1, column: 1)).angle == Motion.jiggleAngle)
    }

    @Test("Соседние клетки дрожат не в ногу")
    func neighboursDoNotJiggleInStep() {
        // Одинаковая для всех анимация читается как дрожание всего поля, а не
        // отдельных клеток. Достаточно, чтобы у соседей различалась либо фаза,
        // либо период.
        for row in 1...10 {
            for column in 1...9 {
                let left = JiggleSpec.forCell(Coordinate(row: row, column: column))
                let right = JiggleSpec.forCell(Coordinate(row: row, column: column + 1))
                #expect(left != right, "клетки \(row),\(column) и \(row),\(column + 1) синхронны")
            }
        }
    }

    // MARK: Геометрия корабля на поле

    @Test("Клетка на поле стоит там, где её ждёт координата")
    func cellOriginMatchesTheCoordinate() {
        let m = BoardMetrics(cell: 32, gap: 3)
        #expect(m.cellOrigin(Coordinate(row: 1, column: 1)) == .zero)
        let third = m.cellOrigin(Coordinate(row: 3, column: 2))
        #expect(third.x == 35)
        #expect(third.y == 70)
    }

    @Test("Размер корабля складывается из клеток и зазоров")
    func shipSizeAddsUp() {
        let m = BoardMetrics(cell: 32, gap: 3)
        let horizontal = m.shipSize(length: 4, orientation: .horizontal)
        let expectedLong: CGFloat = 32 * 4 + 3 * 3
        #expect(horizontal.width == expectedLong)
        #expect(horizontal.height == 32)
        let vertical = m.shipSize(length: 4, orientation: .vertical)
        #expect(vertical.width == 32)
        #expect(vertical.height == expectedLong)
    }

    @Test("Точка вне сетки не превращается в клетку края")
    func pointsOutsideTheGridAreRejected() {
        // Палец легко уходит с поля, и молча зажимать его в край нельзя:
        // корабль встал бы не туда, куда его отпустили.
        let m = BoardMetrics(cell: 32, gap: 3)
        #expect(m.cell(at: CGPoint(x: 5, y: 5)) == Coordinate(row: 1, column: 1))
        #expect(m.cell(at: CGPoint(x: -1, y: 5)) == nil)
        #expect(m.cell(at: CGPoint(x: 5, y: m.gridSide + 10)) == nil)
    }

    // MARK: Розовая клетка

    @Test("Запрет — состояние отрисовки, из ядра правил не приходит")
    func deniedIsNeverProducedByTheCore() {
        // У `CellState` такого состояния нет и быть не должно: запрет живёт,
        // пока корабль ставят, а по правилам игры его в этот момент на поле
        // ещё нет.
        for state in CellState.allCases {
            for side in [Side.you, .foe] {
                #expect(BoardCellState.forDisplay(state, on: side) != .shipDenied)
            }
        }
        #expect(BoardCellState.allCases.contains(.shipDenied))
    }
}
