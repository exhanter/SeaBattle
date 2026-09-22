//
//  Board.swift
//  SeaBattle
//
//  R0.3, pure rules core. ONE implementation of "what happens when a cell is
//  fired at". Before this the rules lived in three places at once — the engine
//  for the computer game, `HotSeatGame.fire` for two players on one device and
//  `NetworkGame.resolveIncomingShot` for network play — each deciding
//  hit / sunk / game-over on its own (audit finding A1). The paper game would
//  have been a fourth copy.
//
//  `Board` is a plain value type: no observation, no sound, no persistence, no
//  UI. It holds the truth about one side's field and mutates only through
//  `apply(shotAt:)` and the explicit paper-game marking methods.
//

import Foundation

/// What is known about a single cell. These five map onto the six states the
/// design draws: `hit` renders differently on your own board (fire on your
/// hull) than on the opponent's (a breach in the water), but that is a
/// rendering decision, not a rule, so the core does not distinguish them.
enum CellState: String, Codable, Sendable, CaseIterable {
    /// Never fired at, no ship known to be here.
    case water
    /// Fired at, empty.
    case miss
    /// A ship segment that has not been fired at. Only ever shown on a board
    /// whose fleet the viewer is allowed to see.
    case ship
    /// A ship segment that was hit while the ship is still afloat.
    case hit
    /// A segment of a ship that has been completely destroyed.
    case sunk

    /// Whether firing here would produce new information.
    var isUnshot: Bool { self == .water || self == .ship }
    /// Whether a ship is known to occupy this cell.
    var holdsKnownShip: Bool { self == .hit || self == .sunk }
}

/// One side's 10 x 10 field.
struct Board: Codable, Sendable, Equatable {

    static let size = 10
    static let cellCount = size * size

    /// The fleet, when it is known. Empty on a board the app is only tracking
    /// rather than simulating — that is the opponent's field in the paper game,
    /// where the fleet lives on the other player's sheet of paper.
    private(set) var ships: [ShipPlacement]

    /// Row-major, 100 entries. A flat array rather than `[[CellState]]`: the
    /// old nested version was built by appending a shared growing array and
    /// silently came out ragged (audit finding A8). A single flat buffer of a
    /// fixed length cannot have that shape at all.
    private var states: [CellState]

    // MARK: - Creating

    /// A board with a known fleet: your own field, or the computer's.
    init(ships: [ShipPlacement]) {
        self.ships = ships
        self.states = Array(repeating: .water, count: Self.cellCount)
        for ship in ships {
            for cell in ship.cells where cell.isOnBoard {
                self[cell] = .ship
            }
        }
    }

    /// A board with no known fleet, every cell untouched.
    init() {
        self.init(ships: [])
    }

    /// A fresh random arrangement of the standard fleet.
    static func randomFleet() -> Board {
        Board(ships: FleetLayout.random())
    }

    // MARK: - Reading

    subscript(_ coordinate: Coordinate) -> CellState {
        get {
            precondition(coordinate.isOnBoard, "Coordinate \(coordinate) is off the board")
            return states[Self.index(of: coordinate)]
        }
        set {
            precondition(coordinate.isOnBoard, "Coordinate \(coordinate) is off the board")
            states[Self.index(of: coordinate)] = newValue
        }
    }

    subscript(row row: Int, column column: Int) -> CellState {
        get { self[Coordinate(row: row, column: column)] }
        set { self[Coordinate(row: row, column: column)] = newValue }
    }

    private static func index(of coordinate: Coordinate) -> Int {
        (coordinate.row - 1) * size + (coordinate.column - 1)
    }

    /// Every coordinate on the board, row by row.
    static var allCoordinates: [Coordinate] {
        (1...size).flatMap { row in (1...size).map { Coordinate(row: row, column: $0) } }
    }

    func ship(at coordinate: Coordinate) -> ShipPlacement? {
        ships.first { $0.contains(coordinate) }
    }

    /// Whether every cell of the ship has been destroyed.
    func isSunk(_ ship: ShipPlacement) -> Bool {
        ship.cells.allSatisfy { self[$0] == .sunk }
    }

    /// Whether the ship has taken all the hits it can, so the next hit sinks it.
    private func isFullyHit(_ ship: ShipPlacement) -> Bool {
        ship.cells.allSatisfy { self[$0].holdsKnownShip }
    }

    /// Number of destroyed ships. When the fleet is known this counts sunk
    /// ships directly; otherwise it counts connected runs of `.sunk` cells,
    /// which is how the paper game keeps score without ever learning the
    /// opponent's layout.
    var sunkShipCount: Int {
        if !ships.isEmpty {
            return ships.count(where: { isSunk($0) })
        }
        return sunkClusters().count
    }

    /// The fleet is gone. On a board with a known fleet that means every ship
    /// is sunk; on a tracked board, that ten runs of sunk cells were marked.
    var isFleetDestroyed: Bool {
        if !ships.isEmpty {
            return ships.allSatisfy { isSunk($0) }
        }
        return sunkShipCount >= FleetLayout.shipCount
    }

    /// The same field as the other player sees it: the fleet is hidden and an
    /// unharmed ship cell reads as untouched water. Hits, sunk ships and misses
    /// are public and stay.
    ///
    /// Anything choosing where to shoot MUST work from this rather than from
    /// the board itself, or it is reading the hidden layout.
    func opponentView() -> Board {
        var view = Board()
        view.states = states.map { $0 == .ship ? .water : $0 }
        return view
    }

    /// Cells that are still worth firing at.
    ///
    /// Replaces the old "pick random coordinates until one happens to be free"
    /// loop, whose expected number of tries grew without bound as the board
    /// filled up (audit finding B16). Callers pick from this list directly.
    ///
    /// - Parameter excludingRingsAroundSunk: also drop the cells around a sunk
    ///   ship. Ships never touch, so no ship can be there — the harder AI
    ///   levels use this, `.easy` does not.
    func shootableCells(excludingRingsAroundSunk: Bool = false) -> [Coordinate] {
        var excluded = Set<Coordinate>()
        if excludingRingsAroundSunk {
            for coordinate in Self.allCoordinates where self[coordinate] == .sunk {
                excluded.formUnion(coordinate.neighbours)
            }
        }
        return Self.allCoordinates.filter { self[$0].isUnshot && !excluded.contains($0) }
    }

    /// The lengths of the ships that have not been sunk, inferred from what is
    /// publicly visible — the sunk clusters — rather than from `ships`. The AI
    /// must not read the hidden layout, so it asks for this.
    func remainingShipLengths() -> [Int] {
        var fleet = FleetLayout.deckCounts
        for cluster in sunkClusters() {
            if let index = fleet.firstIndex(of: cluster.count) {
                fleet.remove(at: index)
            }
        }
        return fleet
    }

    /// Connected runs of `.sunk` cells, found orthogonally. Ships never touch,
    /// so one run is exactly one destroyed ship.
    func sunkClusters() -> [[Coordinate]] {
        var visited = Set<Coordinate>()
        var clusters: [[Coordinate]] = []
        for start in Self.allCoordinates where self[start] == .sunk && !visited.contains(start) {
            var cluster: [Coordinate] = []
            var stack = [start]
            visited.insert(start)
            while let current = stack.popLast() {
                cluster.append(current)
                for neighbour in current.orthogonalNeighbours
                where self[neighbour] == .sunk && !visited.contains(neighbour) {
                    visited.insert(neighbour)
                    stack.append(neighbour)
                }
            }
            clusters.append(cluster)
        }
        return clusters
    }

    // MARK: - Firing

    /// What a shot did.
    enum ShotResult: Sendable, Equatable {
        /// Empty water.
        case miss
        /// A ship was hit and is still afloat.
        case hit(shipID: UUID?)
        /// The hit finished the ship off.
        case sunk(ship: ShipPlacement)
        /// The cell was already known. Allowed by the rules: the splash plays,
        /// the state does not change, and the turn passes (spec 4.4). The
        /// associated state tells a "repeat hit" from a "repeat shot".
        case repeated(CellState)
        /// The coordinate was outside the field. Should not happen from the UI.
        case offBoard

        /// Whether the shooter keeps the turn. Only a genuine hit does.
        var keepsTurn: Bool {
            switch self {
            case .hit, .sunk: return true
            case .miss, .repeated, .offBoard: return false
            }
        }

        var isHit: Bool {
            switch self {
            case .hit, .sunk: return true
            default: return false
            }
        }
    }

    /// Fires at a cell and reports what happened.
    @discardableResult
    mutating func apply(shotAt coordinate: Coordinate) -> ShotResult {
        guard coordinate.isOnBoard else { return .offBoard }

        switch self[coordinate] {
        case .miss, .hit, .sunk:
            return .repeated(self[coordinate])

        case .water:
            self[coordinate] = .miss
            return .miss

        case .ship:
            self[coordinate] = .hit
            guard let ship = ship(at: coordinate) else {
                // A `.ship` cell with no ship behind it means the board was
                // built inconsistently; treat it as a plain hit rather than
                // crashing a game in progress.
                return .hit(shipID: nil)
            }
            if isFullyHit(ship) {
                markSunk(ship)
                return .sunk(ship: ship)
            }
            return .hit(shipID: ship.id)
        }
    }

    /// Turns every cell of the ship to `.sunk`.
    private mutating func markSunk(_ ship: ShipPlacement) {
        for cell in ship.cells where cell.isOnBoard {
            self[cell] = .sunk
        }
    }

    /// Fills the still-untouched ring around a sunk ship with misses. This is
    /// the optional beginner protection ("reveal empty cells around sunk
    /// ships"), off by default — firing there stays legal either way.
    mutating func revealRing(around ship: ShipPlacement) {
        for cell in ship.ring where self[cell] == .water {
            self[cell] = .miss
        }
    }

    // MARK: - Manual marking (paper game)

    /// Records an outcome the player was told out loud, on a board whose fleet
    /// the app does not know. Used only by the paper game (spec 4.5).
    mutating func mark(_ state: CellState, at coordinate: Coordinate) {
        guard coordinate.isOnBoard else { return }
        self[coordinate] = state
    }

    /// Marks the whole run of hits connected to `coordinate` as sunk.
    ///
    /// In the paper game "убит" is only ever entered by hand, because the app
    /// cannot see the opponent's fleet. The boundaries are unambiguous anyway:
    /// ships never touch, so the destroyed ship is exactly the straight run of
    /// hits around the cell that was just called.
    mutating func markSunkRun(from coordinate: Coordinate) {
        guard coordinate.isOnBoard, self[coordinate].holdsKnownShip else { return }
        var visited: Set<Coordinate> = [coordinate]
        var stack = [coordinate]
        while let current = stack.popLast() {
            self[current] = .sunk
            for neighbour in current.orthogonalNeighbours
            where self[neighbour].holdsKnownShip && !visited.contains(neighbour) {
                visited.insert(neighbour)
                stack.append(neighbour)
            }
        }
    }
}
