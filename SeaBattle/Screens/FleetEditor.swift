//
//  FleetEditor.swift
//  Sea Battle — состояние расстановки флота (R2.2)
//
//  Спека 4.4. Здесь только логика взаимодействия, без SwiftUI: что показано,
//  что подвижно, какие корабли розовые и можно ли нажать «Готово». Правила
//  расстановки при этом не дублируются — конфликты считает ядро
//  (`FleetLayout.conflicts(in:)`), а ядро о расстановке как о процессе не знает.
//
//  Вынесено из экрана потому, что правил здесь больше, чем видно на первый
//  взгляд: корабль, отпущенный в запретной зоне, **остаётся там**, поворот
//  ведёт себя так же, а «Готово» держится на непустом множестве конфликтов.
//  Всё это проверяется тестом, а не нажатиями.
//

import Foundation

struct FleetEditor: Equatable, Sendable {

    /// Флот на поле. Порядок — как отдаёт `FleetLayout`: от длинных к коротким.
    private(set) var ships: [ShipPlacement]
    /// Режим изменения: клетки кораблей дрожат, корабль можно тянуть и вращать.
    private(set) var isEditing = false
    /// Корабль, который тянут прямо сейчас. Он полупрозрачный и **не дрожит**.
    private(set) var draggingID: UUID?
    /// Где корабль стоял в момент взятия. Смещение считается от него, а не от
    /// текущего места: иначе каждое событие жеста прибавлялось бы к уже
    /// сдвинутому кораблю, и он уезжал бы в несколько раз дальше пальца.
    private var dragOrigin: Coordinate?

    init(ships: [ShipPlacement] = FleetLayout.random()) {
        self.ships = ships
    }

    // MARK: Что видно

    /// Корабли, стоящие в запрещённой позиции: наложились, коснулись соседа или
    /// свесились с поля. Ровно их дизайн красит розовым.
    var conflicts: Set<UUID> { FleetLayout.conflicts(in: ships) }

    var hasConflicts: Bool { !conflicts.isEmpty }

    /// Чем именно плоха расстановка. Ядру это различие не нужно — запрещено и
    /// то и другое, — но `WarningLine` (спека 2.16) говорит разное: «Клетка
    /// занята» при наложении и «Нужен зазор в одну клетку» при касании.
    /// Наложение сильнее: если есть и то и другое, игроку надо сказать про
    /// занятую клетку, потому что она заметнее.
    var conflictKind: ConflictKind? {
        guard hasConflicts else { return nil }
        var occupied = Set<Coordinate>()
        for ship in ships {
            for cell in ship.cells where !occupied.insert(cell).inserted {
                return .overlap
            }
        }
        return .touching
    }

    enum ConflictKind: Equatable, Sendable {
        /// Корабли заняли одну и ту же клетку.
        case overlap
        /// Корабли только соприкоснулись — между ними нет клетки воды.
        case touching
    }

    /// «Старт» и «Готово» неактивны, пока на поле есть ошибка, — иначе партия
    /// началась бы с флотом, который правилам не соответствует.
    var canFinish: Bool { !hasConflicts }

    /// Пока корабль тянут, обе кнопки гаснут: нажать их всё равно нечем, а
    /// мигание кнопок под пальцем отвлекает от поля.
    var actionsEnabled: Bool { draggingID == nil }

    func ship(id: UUID) -> ShipPlacement? { ships.first { $0.id == id } }

    /// Корабль под клеткой, если он там есть. Так находят, что тянуть и что
    /// поворачивать.
    func ship(at coordinate: Coordinate) -> ShipPlacement? {
        ships.first { $0.contains(coordinate) }
    }

    // MARK: Действия

    /// «Перемешать» — другая случайная расстановка. Работает и в режиме
    /// изменения: это единственный способ выбраться из положения, которое игрок
    /// сам распутывать не хочет.
    mutating func shuffle() {
        ships = FleetLayout.random()
        endDragging()
    }

    mutating func beginEditing() {
        isEditing = true
    }

    /// «Готово». Не делает ничего, пока на поле есть ошибка: иначе режим
    /// закрылся бы с розовым кораблём на виду.
    @discardableResult
    mutating func finishEditing() -> Bool {
        guard canFinish else { return false }
        isEditing = false
        endDragging()
        return true
    }

    mutating func beginDragging(_ id: UUID) {
        guard isEditing, let ship = ship(id: id) else { return }
        draggingID = id
        dragOrigin = ship.origin
    }

    /// Смещение корабля в клетках **от места взятия**. Позиция не проверяется:
    /// корабль свободно ходит по полю и краснеет, а не упирается в невидимую
    /// стену.
    ///
    /// Единственное ограничение — корабль целиком остаётся на поле: за краем
    /// его не видно, а «Готово» тогда блокируется по причине, которой игрок не
    /// видит.
    mutating func dragBy(columns: Int, rows: Int) {
        guard let id = draggingID, let start = dragOrigin else { return }
        move(id, to: Coordinate(row: start.row + rows, column: start.column + columns))
    }

    /// Переставить корабль в клетку. Отдельно от жеста — этим же пользуются
    /// превью и тесты.
    mutating func move(_ id: UUID, to origin: Coordinate) {
        guard let index = ships.firstIndex(where: { $0.id == id }) else { return }
        ships[index] = ships[index].moved(to: clamped(origin, for: ships[index]))
    }

    /// Отпустили палец. Корабль остаётся там, где его отпустили, **даже если
    /// позиция запрещена** — по спеке 4.4 это осознанно: возврат на прежнее
    /// место скрывал бы ошибку, а розовый корабль и погашенное «Готово»
    /// заставляют переставить.
    mutating func endDragging() {
        draggingID = nil
        dragOrigin = nil
    }

    /// Поворот коротким касанием. Вокруг середины корабля, а не вокруг начала,
    /// поэтому корабль не «прыгает» из-под пальца. Если после поворота корабль
    /// не влезает на поле, он сдвигается внутрь — и может стать розовым, это
    /// нормально.
    mutating func rotate(_ id: UUID) {
        guard isEditing, let index = ships.firstIndex(where: { $0.id == id }) else { return }
        let rotated = ships[index].rotated()
        ships[index] = rotated.moved(to: clamped(rotated.origin, for: rotated))
    }

    /// Загоняет начало корабля в поле, чтобы корабль целиком остался на нём.
    private func clamped(_ origin: Coordinate, for ship: ShipPlacement) -> Coordinate {
        let maxRow = ship.orientation == .vertical ? Board.size - ship.length + 1 : Board.size
        let maxColumn = ship.orientation == .horizontal ? Board.size - ship.length + 1 : Board.size
        return Coordinate(row: min(max(1, origin.row), maxRow),
                          column: min(max(1, origin.column), maxColumn))
    }
}

// MARK: - Дрожание клеток

/// Дрожание при расстановке — одна из двух бесконечных анимаций в игре
/// (спека 5). Каждая клетка дрожит **сама по себе**, как иконки на домашнем
/// экране: одинаковая для всех анимация читается как дрожание всего поля.
///
/// Период и сдвиг фазы выбираются по клетке и **не меняются между перерисовками**
/// — иначе на каждом обновлении экрана дрожание перезапускалось бы с новой
/// случайной фазой, и поле дёргалось бы вместо того, чтобы дрожать. Поэтому
/// значения считаются от координаты, а не берутся из генератора случайных чисел.
struct JiggleSpec: Equatable, Sendable {
    let period: Double
    let phase: Double
    /// Поворот ±, в градусах.
    var angle: Double { Motion.jiggleAngle }

    /// Четыре периода с шагом 0,035 от 0,40 и девять сдвигов фазы с шагом 0,03
    /// от нуля — числа из спеки 4.4.
    static let periods: [Double] = (0..<4).map { Motion.jiggleRange.lowerBound + Double($0) * 0.035 }
    static let phases: [Double] = (0..<9).map { Double($0) * 0.03 }

    static func forCell(_ coordinate: Coordinate) -> JiggleSpec {
        // Два разных множителя, иначе период и фаза шли бы по клетке в ногу и
        // соседние клетки дрожали бы одинаково по диагонали.
        let periodIndex = (coordinate.row * 3 + coordinate.column * 5) % periods.count
        let phaseIndex = (coordinate.row * 7 + coordinate.column * 2) % phases.count
        return JiggleSpec(period: periods[periodIndex], phase: phases[phaseIndex])
    }
}
