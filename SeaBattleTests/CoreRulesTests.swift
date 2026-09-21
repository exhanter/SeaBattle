//
//  CoreRulesTests.swift
//  SeaBattleTests
//
//  R0.3: the pure rules core is the one place the game's rules live, so it is
//  the one place worth testing thoroughly. Everything here is value types and
//  pure functions — no app state, no main actor, no simulator dependencies.
//

import Foundation
import Testing
@testable import SeaBattle

/// Deterministic xorshift64, so a failing random layout can be reproduced from
/// its seed instead of being a once-in-a-thousand mystery.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Scramble the seed so that 0, 1, 2… don't produce correlated streams.
        state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Coordinates

struct CoordinateTests {

    @Test("Only 1...10 in both axes is on the board")
    func boundsCheck() {
        #expect(Coordinate(row: 1, column: 1).isOnBoard)
        #expect(Coordinate(row: 10, column: 10).isOnBoard)
        #expect(!Coordinate(row: 0, column: 5).isOnBoard)
        #expect(!Coordinate(row: 11, column: 5).isOnBoard)
        #expect(!Coordinate(row: 5, column: 0).isOnBoard)
        #expect(!Coordinate(row: 5, column: 11).isOnBoard)
    }

    @Test("Neighbours are clipped at the edges")
    func neighboursAreClipped() {
        #expect(Coordinate(row: 5, column: 5).neighbours.count == 8)
        #expect(Coordinate(row: 1, column: 1).neighbours.count == 3)
        #expect(Coordinate(row: 1, column: 5).neighbours.count == 5)
        #expect(Coordinate(row: 10, column: 10).neighbours.count == 3)

        #expect(Coordinate(row: 5, column: 5).orthogonalNeighbours.count == 4)
        #expect(Coordinate(row: 1, column: 1).orthogonalNeighbours.count == 2)
    }

    @Test("Every coordinate on the board is listed once")
    func allCoordinates() {
        let all = Board.allCoordinates
        #expect(all.count == 100)
        #expect(Set(all).count == 100)
        #expect(all.allSatisfy { $0.isOnBoard })
    }
}

// MARK: - Ship placement

struct ShipPlacementTests {

    @Test("Cells are derived from origin, length and orientation")
    func cellsAreDerived() {
        let horizontal = ShipPlacement(length: 3, origin: Coordinate(row: 2, column: 4), orientation: .horizontal)
        #expect(horizontal.cells == [Coordinate(row: 2, column: 4),
                                     Coordinate(row: 2, column: 5),
                                     Coordinate(row: 2, column: 6)])

        let vertical = ShipPlacement(length: 3, origin: Coordinate(row: 2, column: 4), orientation: .vertical)
        #expect(vertical.cells == [Coordinate(row: 2, column: 4),
                                   Coordinate(row: 3, column: 4),
                                   Coordinate(row: 4, column: 4)])
    }

    @Test("contains agrees with the derived cells")
    func containsAgreesWithCells() {
        for orientation in Orientation.allCases {
            for length in 1...4 {
                let ship = ShipPlacement(length: length,
                                         origin: Coordinate(row: 3, column: 3),
                                         orientation: orientation)
                let cells = Set(ship.cells)
                for coordinate in Board.allCoordinates {
                    #expect(ship.contains(coordinate) == cells.contains(coordinate))
                }
            }
        }
    }

    @Test("A ship running off the edge is not on the board")
    func offBoardDetection() {
        #expect(ShipPlacement(length: 4, origin: Coordinate(row: 1, column: 7), orientation: .horizontal).isOnBoard)
        #expect(!ShipPlacement(length: 4, origin: Coordinate(row: 1, column: 8), orientation: .horizontal).isOnBoard)
        #expect(!ShipPlacement(length: 2, origin: Coordinate(row: 10, column: 1), orientation: .vertical).isOnBoard)
    }

    @Test("The ring is the footprint without the ship itself")
    func ringExcludesOwnCells() {
        let ship = ShipPlacement(length: 2, origin: Coordinate(row: 5, column: 5), orientation: .horizontal)
        let own = Set(ship.cells)
        let ring = Set(ship.ring)

        #expect(ring.isDisjoint(with: own))
        #expect(ring.union(own) == ship.footprint)
        // A 1 x 2 ship in open water has a 3 x 4 footprint: 12 - 2 = 10.
        #expect(ring.count == 10)
        #expect(ring.allSatisfy { $0.isOnBoard })
    }

    @Test("Rotating twice returns the ship to where it started")
    func rotationIsReversible() {
        for length in 1...4 {
            for orientation in Orientation.allCases {
                let ship = ShipPlacement(length: length,
                                         origin: Coordinate(row: 4, column: 4),
                                         orientation: orientation)
                let back = ship.rotated().rotated()
                #expect(back.origin == ship.origin)
                #expect(back.orientation == ship.orientation)
                #expect(back.id == ship.id)
            }
        }
    }

    @Test("Rotation keeps the ship around its middle, not its origin")
    func rotationPivotsAroundTheMiddle() {
        // A 4-deck ship lying on row 5 from column 4 pivots on column 5, so it
        // stands up spanning rows 4...7 in column 5 — it does not swing away
        // from (5, 4).
        let ship = ShipPlacement(length: 4, origin: Coordinate(row: 5, column: 4), orientation: .horizontal)
        let rotated = ship.rotated()
        #expect(rotated.orientation == .vertical)
        #expect(rotated.origin == Coordinate(row: 4, column: 5))
        #expect(Set(ship.cells).intersection(rotated.cells).isEmpty == false)
    }

    @Test("Moving changes only the origin")
    func movingKeepsIdentity() {
        let ship = ShipPlacement(length: 3, origin: Coordinate(row: 1, column: 1), orientation: .vertical)
        let moved = ship.moved(to: Coordinate(row: 7, column: 2))
        #expect(moved.id == ship.id)
        #expect(moved.length == ship.length)
        #expect(moved.orientation == ship.orientation)
        #expect(moved.origin == Coordinate(row: 7, column: 2))
    }
}

// MARK: - Fleet layout

struct FleetLayoutTests {

    @Test("The canonical layout is a legal full fleet")
    func canonicalLayoutIsValid() {
        let ships = FleetLayout.canonicalLayout()
        #expect(ships.count == FleetLayout.shipCount)
        #expect(FleetLayout.isValid(ships))
        #expect(ships.flatMap(\.cells).count == FleetLayout.occupiedCellCount)
    }

    @Test("A random layout is always a legal full fleet", arguments: 0..<200 as Range<UInt64>)
    func randomLayoutIsValid(seed: UInt64) {
        var generator = SeededGenerator(seed: seed)
        let ships = FleetLayout.random(using: &generator)

        #expect(ships.count == FleetLayout.shipCount)
        #expect(ships.map(\.length).sorted(by: >) == FleetLayout.deckCounts)
        #expect(ships.allSatisfy { $0.isOnBoard })
        #expect(FleetLayout.conflicts(in: ships).isEmpty, "Seed \(seed) produced a touching or overlapping fleet")
        #expect(Set(ships.flatMap(\.cells)).count == FleetLayout.occupiedCellCount,
                "Seed \(seed) produced overlapping ships")
        // Returned longest-first so the UI can address ships in a stable order.
        #expect(ships.map(\.length) == FleetLayout.deckCounts)
    }

    @Test("The same seed always produces the same layout")
    func randomLayoutIsReproducible() {
        // Identity is deliberately fresh on every ship — only the geometry is
        // a function of the seed, and that is what makes a failure replayable.
        func geometry(_ ships: [ShipPlacement]) -> [String] {
            ships.map { "\($0.length)@\($0.origin.row),\($0.origin.column)/\($0.orientation.rawValue)" }
        }
        var first = SeededGenerator(seed: 12_345)
        var second = SeededGenerator(seed: 12_345)
        var third = SeededGenerator(seed: 54_321)

        let a = FleetLayout.random(using: &first)
        let b = FleetLayout.random(using: &second)
        let c = FleetLayout.random(using: &third)

        #expect(geometry(a) == geometry(b))
        #expect(geometry(a) != geometry(c))
        #expect(Set(a.map(\.id)).isDisjoint(with: b.map(\.id)))
    }

    @Test("Overlapping ships are reported as conflicting")
    func overlapIsAConflict() {
        let a = ShipPlacement(length: 3, origin: Coordinate(row: 5, column: 5), orientation: .horizontal)
        let b = ShipPlacement(length: 2, origin: Coordinate(row: 5, column: 6), orientation: .vertical)
        let conflicts = FleetLayout.conflicts(in: [a, b])
        #expect(conflicts == [a.id, b.id])
    }

    @Test("Ships that merely touch — including diagonally — are conflicting")
    func touchingIsAConflict() {
        let a = ShipPlacement(length: 2, origin: Coordinate(row: 5, column: 5), orientation: .horizontal)

        let sideBySide = ShipPlacement(length: 1, origin: Coordinate(row: 5, column: 7), orientation: .horizontal)
        #expect(!FleetLayout.conflicts(in: [a, sideBySide]).isEmpty)

        let diagonal = ShipPlacement(length: 1, origin: Coordinate(row: 6, column: 7), orientation: .horizontal)
        #expect(!FleetLayout.conflicts(in: [a, diagonal]).isEmpty)

        // One clear cell is enough.
        let apart = ShipPlacement(length: 1, origin: Coordinate(row: 5, column: 8), orientation: .horizontal)
        #expect(FleetLayout.conflicts(in: [a, apart]).isEmpty)
    }

    @Test("A ship hanging off the board is conflicting on its own")
    func offBoardIsAConflict() {
        let ship = ShipPlacement(length: 3, origin: Coordinate(row: 10, column: 9), orientation: .horizontal)
        #expect(FleetLayout.conflicts(in: [ship]) == [ship.id])
    }

    @Test("A fleet with the wrong ships is not valid even when nothing touches")
    func wrongFleetIsInvalid() {
        let tooFew = Array(FleetLayout.canonicalLayout().dropLast())
        #expect(FleetLayout.conflicts(in: tooFew).isEmpty)
        #expect(!FleetLayout.isValid(tooFew))
    }
}

// MARK: - Board: firing

struct BoardFiringTests {

    /// A board with a single 3-deck ship on row 5, columns 5...7.
    private func boardWithOneShip() -> (Board, ShipPlacement) {
        let ship = ShipPlacement(length: 3, origin: Coordinate(row: 5, column: 5), orientation: .horizontal)
        return (Board(ships: [ship]), ship)
    }

    @Test("A new board is all water except the ships")
    func initialState() {
        let (board, ship) = boardWithOneShip()
        for coordinate in Board.allCoordinates {
            #expect(board[coordinate] == (ship.contains(coordinate) ? .ship : .water))
        }
    }

    @Test("Firing at empty water is a miss and passes the turn")
    func missPassesTheTurn() {
        var (board, _) = boardWithOneShip()
        let result = board.apply(shotAt: Coordinate(row: 1, column: 1))
        #expect(result == .miss)
        #expect(!result.keepsTurn)
        #expect(!result.isHit)
        #expect(board[row: 1, column: 1] == .miss)
    }

    @Test("Hitting a ship that survives keeps the turn")
    func hitKeepsTheTurn() {
        var (board, ship) = boardWithOneShip()
        let result = board.apply(shotAt: Coordinate(row: 5, column: 5))
        #expect(result == .hit(shipID: ship.id))
        #expect(result.keepsTurn)
        #expect(board[row: 5, column: 5] == .hit)
        #expect(board.sunkShipCount == 0)
        #expect(!board.isFleetDestroyed)
    }

    @Test("The last hit sinks the ship and marks all of its cells")
    func lastHitSinks() {
        var (board, ship) = boardWithOneShip()
        #expect(board.apply(shotAt: Coordinate(row: 5, column: 5)).isHit)
        #expect(board.apply(shotAt: Coordinate(row: 5, column: 7)).isHit)

        let result = board.apply(shotAt: Coordinate(row: 5, column: 6))
        #expect(result == .sunk(ship: ship))
        #expect(result.keepsTurn)
        #expect(ship.cells.allSatisfy { board[$0] == .sunk })
        #expect(board.isSunk(ship))
        #expect(board.sunkShipCount == 1)
        #expect(board.isFleetDestroyed)
    }

    @Test("A one-deck ship sinks on the first hit")
    func singleDeckSinksImmediately() {
        let ship = ShipPlacement(length: 1, origin: Coordinate(row: 3, column: 3), orientation: .horizontal)
        var board = Board(ships: [ship])
        #expect(board.apply(shotAt: Coordinate(row: 3, column: 3)) == .sunk(ship: ship))
    }

    @Test("Firing at a known cell changes nothing and passes the turn")
    func repeatShotIsAllowedButInert() {
        var (board, _) = boardWithOneShip()

        board.apply(shotAt: Coordinate(row: 1, column: 1))
        let repeatMiss = board.apply(shotAt: Coordinate(row: 1, column: 1))
        #expect(repeatMiss == .repeated(.miss))
        #expect(!repeatMiss.keepsTurn)
        #expect(board[row: 1, column: 1] == .miss)

        board.apply(shotAt: Coordinate(row: 5, column: 5))
        let repeatHit = board.apply(shotAt: Coordinate(row: 5, column: 5))
        #expect(repeatHit == .repeated(.hit))
        // A repeat hit does not keep the turn either — it is not new damage.
        #expect(!repeatHit.keepsTurn)
        #expect(board[row: 5, column: 5] == .hit)
    }

    @Test("A shot outside the field is rejected without changing the board")
    func offBoardShotIsRejected() {
        var (board, _) = boardWithOneShip()
        let before = board
        #expect(board.apply(shotAt: Coordinate(row: 0, column: 5)) == .offBoard)
        #expect(board.apply(shotAt: Coordinate(row: 11, column: 5)) == .offBoard)
        #expect(board == before)
    }

    @Test("Sinking the whole fleet ends the match")
    func fullFleetCanBeDestroyed() {
        var board = Board(ships: FleetLayout.canonicalLayout())
        #expect(!board.isFleetDestroyed)

        for coordinate in Board.allCoordinates {
            board.apply(shotAt: coordinate)
        }
        #expect(board.sunkShipCount == FleetLayout.shipCount)
        #expect(board.isFleetDestroyed)
        #expect(board.shootableCells().isEmpty)
    }
}

// MARK: - Board: derived information

struct BoardKnowledgeTests {

    @Test("Shootable cells shrink by exactly one per new shot")
    func shootableCellsShrink() {
        var board = Board(ships: FleetLayout.canonicalLayout())
        #expect(board.shootableCells().count == 100)

        board.apply(shotAt: Coordinate(row: 10, column: 1))
        #expect(board.shootableCells().count == 99)

        // A repeat shot reveals nothing, so the count stays put.
        board.apply(shotAt: Coordinate(row: 10, column: 1))
        #expect(board.shootableCells().count == 99)
    }

    @Test("Sinking a ship can also rule out the ring around it")
    func ringCanBeExcluded() {
        let ship = ShipPlacement(length: 2, origin: Coordinate(row: 5, column: 5), orientation: .horizontal)
        var board = Board(ships: [ship])
        for cell in ship.cells { board.apply(shotAt: cell) }

        let lenient = board.shootableCells(excludingRingsAroundSunk: false)
        let strict = board.shootableCells(excludingRingsAroundSunk: true)
        #expect(lenient.count == 98)
        // The ten ring cells around a 1 x 2 ship are no longer worth firing at.
        #expect(strict.count == 88)
        #expect(Set(lenient).subtracting(strict) == Set(ship.ring))
    }

    @Test("Revealing the ring marks only untouched cells")
    func revealRingOnlyTouchesWater() {
        let ship = ShipPlacement(length: 2, origin: Coordinate(row: 5, column: 5), orientation: .horizontal)
        let other = ShipPlacement(length: 1, origin: Coordinate(row: 4, column: 8), orientation: .horizontal)
        var board = Board(ships: [ship, other])
        for cell in ship.cells { board.apply(shotAt: cell) }

        board.revealRing(around: ship)
        for cell in ship.ring {
            #expect(board[cell] == .miss)
        }
        // The other ship is outside this ring and stays hidden.
        #expect(board[row: 4, column: 8] == .ship)
        #expect(ship.cells.allSatisfy { board[$0] == .sunk })
    }

    @Test("Remaining ship lengths are inferred from sunk clusters only")
    func remainingLengthsUsePublicInformation() {
        var board = Board(ships: FleetLayout.canonicalLayout())
        #expect(board.remainingShipLengths() == FleetLayout.deckCounts)

        // Sink the 4-deck ship on row 1, columns 1...4.
        for column in 1...4 {
            board.apply(shotAt: Coordinate(row: 1, column: column))
        }
        #expect(board.remainingShipLengths() == [3, 3, 2, 2, 2, 1, 1, 1, 1])

        // Damaging a ship without sinking it must not remove it from the list.
        board.apply(shotAt: Coordinate(row: 3, column: 1))
        #expect(board.remainingShipLengths() == [3, 3, 2, 2, 2, 1, 1, 1, 1])
    }
}

// MARK: - Board: manual marking (paper game)

struct PaperBoardTests {

    @Test("A tracked board starts empty and knows no fleet")
    func trackedBoardIsEmpty() {
        let board = Board()
        #expect(board.ships.isEmpty)
        #expect(board.sunkShipCount == 0)
        #expect(!board.isFleetDestroyed)
        #expect(board.shootableCells().count == 100)
    }

    @Test("Outcomes heard out loud are recorded by hand")
    func marksAreRecorded() {
        var board = Board()
        board.mark(.miss, at: Coordinate(row: 1, column: 1))
        board.mark(.hit, at: Coordinate(row: 4, column: 7))
        #expect(board[row: 1, column: 1] == .miss)
        #expect(board[row: 4, column: 7] == .hit)
        #expect(board.shootableCells().count == 98)
    }

    @Test("\"Sunk\" paints the whole connected run of hits")
    func sunkRunPaintsTheWholeShip() {
        var board = Board()
        board.mark(.hit, at: Coordinate(row: 4, column: 5))
        board.mark(.hit, at: Coordinate(row: 4, column: 6))
        board.mark(.hit, at: Coordinate(row: 4, column: 7))
        // An unrelated hit elsewhere must not be swept up.
        board.mark(.hit, at: Coordinate(row: 8, column: 2))

        board.markSunkRun(from: Coordinate(row: 4, column: 7))

        #expect(board[row: 4, column: 5] == .sunk)
        #expect(board[row: 4, column: 6] == .sunk)
        #expect(board[row: 4, column: 7] == .sunk)
        #expect(board[row: 8, column: 2] == .hit)
        #expect(board.sunkShipCount == 1)
        #expect(board.remainingShipLengths() == [4, 3, 2, 2, 2, 1, 1, 1, 1])
    }

    @Test("A vertical run is found too, and a lone hit sinks alone")
    func sunkRunHandlesBothAxes() {
        var board = Board()
        for row in 6...8 { board.mark(.hit, at: Coordinate(row: row, column: 3)) }
        board.markSunkRun(from: Coordinate(row: 6, column: 3))
        #expect((6...8).allSatisfy { board[row: $0, column: 3] == .sunk })

        board.mark(.hit, at: Coordinate(row: 1, column: 10))
        board.markSunkRun(from: Coordinate(row: 1, column: 10))
        #expect(board[row: 1, column: 10] == .sunk)
        #expect(board.sunkShipCount == 2)
    }

    @Test("\"Sunk\" on water or a miss does nothing")
    func sunkRunIgnoresCellsWithoutAHit() {
        var board = Board()
        board.mark(.miss, at: Coordinate(row: 2, column: 2))

        board.markSunkRun(from: Coordinate(row: 2, column: 2))
        board.markSunkRun(from: Coordinate(row: 9, column: 9))

        #expect(board[row: 2, column: 2] == .miss)
        #expect(board[row: 9, column: 9] == .water)
        #expect(board.sunkShipCount == 0)
    }

    @Test("Ten sunk runs end the match on a tracked board")
    func tenRunsFinishTheGame() {
        var board = Board()
        // Ten separated single cells: enough to stand in for ten ships.
        var marked = 0
        for row in stride(from: 1, through: 9, by: 2) {
            for column in stride(from: 1, through: 9, by: 4) where marked < FleetLayout.shipCount {
                board.mark(.hit, at: Coordinate(row: row, column: column))
                board.markSunkRun(from: Coordinate(row: row, column: column))
                marked += 1
            }
        }
        #expect(marked == FleetLayout.shipCount)
        #expect(board.sunkShipCount == FleetLayout.shipCount)
        #expect(board.isFleetDestroyed)
    }
}

// MARK: - Round trip

struct BoardCodingTests {

    @Test("A board survives encoding and decoding")
    func boardRoundTrips() throws {
        var board = Board(ships: FleetLayout.canonicalLayout())
        board.apply(shotAt: Coordinate(row: 1, column: 1))
        board.apply(shotAt: Coordinate(row: 10, column: 10))

        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(Board.self, from: data)
        #expect(decoded == board)
    }

    @Test("Side and orientation have stable raw values")
    func rawValuesAreStable() {
        // These are persisted in saved games and sent over the wire, so the
        // strings must not drift.
        #expect(Side.you.rawValue == "you")
        #expect(Side.foe.rawValue == "foe")
        #expect(Side.you.opposite == .foe)
        #expect(Side.foe.opposite == .you)
        #expect(Orientation.horizontal.toggled == .vertical)
        #expect(CellState.allCases.map(\.rawValue) == ["water", "miss", "ship", "hit", "sunk"])
    }
}
