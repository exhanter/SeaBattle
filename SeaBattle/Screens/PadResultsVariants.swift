//
//  PadResultsVariants.swift
//  Sea Battle — ВРЕМЕННО: варианты итогов на iPad (10.10)
//
//  Заказчик выбирает по превью; после выбора файл удаляется, выбранное
//  переезжает в `MatchResultsModifier`.
//

import SwiftUI

private enum PadResultsSample {
    /// Поражение на «Среднем»: свой флот потоплен целиком, у противника
    /// потоплено 7 из 10, остальные три корабля видны открытыми.
    static let result: MatchResult = {
        var tally = MatchTally()
        for _ in 0..<3 { tally.record(.hit(shipID: nil)) }
        for _ in 0..<14 {
            tally.record(.miss)
            tally.record(.hit(shipID: nil))
        }
        for _ in 0..<27 { tally.record(.miss) }
        tally.recordHint(cost: 3)
        return MatchResult(didWin: false, level: .medium, yourLosses: 10, foeLosses: 7,
                           tally: tally, balance: 76,
                           levelRecord: StatRecord(wins: 21, losses: 11))
    }()

    static let boards: ResultBoards = {
        var own = Board(ships: FleetLayout.canonicalLayout())
        for ship in FleetLayout.canonicalLayout() {
            for cell in ship.cells { _ = own.apply(shotAt: cell) }
        }
        var foe = Board.randomFleet()
        let ships = Board.allCoordinates.compactMap { foe.ship(at: $0) }
        var seen: [ShipPlacement] = []
        for ship in ships where !seen.contains(ship) { seen.append(ship) }
        for ship in seen.prefix(7) {
            for cell in ship.cells { _ = foe.apply(shotAt: cell) }
        }
        var misses = 0
        for cell in Board.allCoordinates where misses < 30 && foe[cell] == .water {
            if (cell.row * 7 + cell.column * 3) % 4 == 0 {
                _ = foe.apply(shotAt: cell)
                misses += 1
            }
        }
        for cell in Board.allCoordinates where own[cell] == .water
            && (cell.row * 5 + cell.column) % 3 == 0 {
            _ = own.apply(shotAt: cell)
        }
        return ResultBoards(own: own, foe: foe)
    }()
}

private struct PadResultsVariant: View {
    let chrome: Geometry.BottomChrome

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            ResultsScreen(result: PadResultsSample.result, onReview: {},
                          boards: PadResultsSample.boards)
        }
        .environment(\.usesPadLayout, true)
        .environment(\.bottomChrome, chrome)
        .preferredColorScheme(.dark)
    }
}

// Капсулы с доком сняты (13.10): заказчик оставил квадраты по углам.

struct PadResults1_Previews: PreviewProvider {
    static var previews: some View {
        PadResultsVariant(chrome: .tiles)
            .padPreview(.portrait, "1 · Квадраты по углам")
    }
}

struct PadResults2_Previews: PreviewProvider {
    static var previews: some View {
        PadResultsVariant(chrome: .tiles)
            .padPreview(.landscapeLeft, "2 · Квадраты по углам · горизонтально")
    }
}
