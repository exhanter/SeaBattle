//
//  BattleSide.swift
//  SeaBattle
//
//  30.10: одна сторона партии против компьютера — наблюдаемая обёртка над
//  полем ядра правил (`Board`). Заменила `PlayerData` с его `Cell` и `Ship`
//  (модель до редизайна): та хранила поле таблицей клеток со смешанными
//  состояниями правил и отрисовки, корабли — отдельным списком с флажком
//  «потоплен», и через мост `PlayerData+Board` переводилась в `Board` на каждом
//  выстреле. Теперь правду о поле держит только `Board`, как в остальных
//  режимах (бумага, вдвоём, по сети); класс нужен лишь затем, чтобы контроллер
//  боя, движок и компьютер смотрели на одно и то же поле.
//

import Foundation
import Observation

@MainActor
@Observable
final class BattleSide {

    /// Чьё это поле: своё (`.you`) или компьютера (`.foe`).
    let side: Side

    /// Вся правда о поле. Меняется только ядром правил: выстрелом
    /// (`Board.apply(shotAt:)`) или новой расстановкой (`place(_:)`).
    var board: Board

    init(side: Side) {
        self.side = side
        self.board = Board(ships: [])
    }

    /// Новая расстановка — флот, который вернуло ядро (расстановка игрока,
    /// `ComputerOpponent.arrangeFleet(for:on:)`, случайная).
    func place(_ layout: [ShipPlacement]) {
        board = Board(ships: layout)
    }

    /// Случайный законный флот.
    func randomFleet() {
        place(FleetLayout.random())
    }

    /// Пустое поле перед новой партией.
    func reset() {
        board = Board(ships: [])
    }

    /// Сколько кораблей этой стороны потоплено — для панели счёта и итогов.
    var sunkShipCount: Int { board.sunkShipCount }
}
