//
//  LayoutPosterior.swift
//  SeaBattle
//
//  13.10: where the rest of a fleet probably is, given what has been seen of
//  it — and given what the board says about HOW it was arranged.
//
//  The heat map `.expert` used before this counts every placement of every
//  remaining ship as equally likely. That is right against a random layout and
//  badly wrong against a hidden one: a player who packs the fleet against the
//  edges and against each other puts ships exactly where the map is coldest,
//  and on 13.10 won ten matches out of ten that way.
//
//  This counts whole fleets instead, and weights each by how much water it
//  gives away — `exp(-strength × ringExposure)`, the same weighting the
//  computer hides its own fleet with. The strength is not assumed but
//  inferred, from nothing but this board: several are sampled at once
//  (simulated tempering), and sunk ships that hug the edges and share their
//  rings pull the estimate towards "hidden", while sunk ships out in open water
//  leave it at "random". Nothing is carried over from one match to the next.
//

import Foundation

/// A small seedable generator (SplitMix64), so that a sampled decision can be
/// reproduced from its seed.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

struct LayoutPosterior: Sendable {

    /// One hypothesis about how the fleet was arranged.
    struct Component: Sendable, Equatable {
        /// The weighting `exp(-strength × ringExposure)`. 0 is every legal
        /// layout equally likely; slightly below 0 is what
        /// `FleetLayout.random` actually produces (see `standard`).
        let strength: Double
        /// How likely the hypothesis is before the match starts.
        let prior: Double
        /// `log Z(strength) - log Z(0)` over every legal layout of the full
        /// fleet. Without it a strong hypothesis would win just because its
        /// weights are small numbers, not because it fits.
        let logPartition: Double
    }

    /// What `.expert` believes before the first shot: four in ten that the
    /// fleet is random, the rest spread over ever harder hiding.
    ///
    /// "Random" is −0.15, not 0: `FleetLayout.random` places ships one at a
    /// time, which leaves them a little more exposed than a uniform draw over
    /// whole layouts (62 cells of water against 59.7). With 0 the sampler
    /// looked for an auto-arranged fleet in slightly the wrong places and lost
    /// a shot a match to the heat map it replaced; with −0.15 it is level.
    ///
    /// `logPartition` is measured on the empty board (13.10, 2–4 thousand
    /// layouts per point, trapezoid over steps of 0.05) and only valid for
    /// the standard fleet.
    static let standard = LayoutPosterior(components: {
        let table: [(strength: Double, logPartition: Double)] = [
            (-0.15, 9.126), (0, 0), (0.15, -8.774), (0.3, -17.193), (0.45, -25.247),
            (0.6, -32.906), (0.8, -42.512), (1.0, -51.451), (1.25, -61.858), (1.5, -71.671)
        ]
        let randomShare = 0.4
        let hiddenShare = (1 - randomShare) / Double(table.count - 1)
        return table.enumerated().map { index, entry in
            Component(strength: entry.strength,
                      prior: index == 0 ? randomShare : hiddenShare,
                      logPartition: entry.logPartition)
        }
    }())

    let components: [Component]
    /// Independent chains; more of them guard against one getting stuck.
    var chains = 8
    /// Sweeps thrown away while a chain forgets its random start.
    var burnIn = 15
    /// Sweeps counted per chain.
    var samples = 40
    /// A weight per board index for a ship cell lying there, or nil for none.
    /// Only the opt-in layout memory sets it (`LayoutMemory`): cells this
    /// player has put ships on before weigh more.
    var cellBias: [Double]? = nil

    /// What the sampler found.
    struct Estimate {
        /// For every board index (`(row - 1) × 10 + column - 1`), the share of
        /// sampled fleets with a ship there. Cells already fired at are 0.
        let occupancy: [Double]
        /// How much of the sampling each component got — the posterior.
        let componentShare: [Double]
    }

    /// RETURNS nil when the board has a damaged ship on it (finishing is a
    /// separate, deterministic decision) or when no consistent fleet could be
    /// found to start from.
    func estimate<G: RandomNumberGenerator>(on board: Board, using generator: inout G) -> Estimate? {
        guard !components.isEmpty else { return nil }
        var forbidden = [Bool](repeating: false, count: Board.cellCount)
        // The sunk ships are known exactly. Their rings are water, and they
        // count towards the exposure like any other ship's.
        var sunkRing = [Int](repeating: 0, count: Board.cellCount)
        for coordinate in Board.allCoordinates {
            switch board[coordinate] {
            case .hit:
                return nil
            case .miss:
                forbidden[Self.index(coordinate)] = true
            case .sunk:
                forbidden[Self.index(coordinate)] = true
                for neighbour in coordinate.neighbours where board[neighbour] != .sunk {
                    forbidden[Self.index(neighbour)] = true
                    sunkRing[Self.index(neighbour)] = 1
                }
            case .water, .ship:
                break
            }
        }

        let lengths = board.remainingShipLengths()
        guard !lengths.isEmpty else { return nil }

        let tables = Tables(lengths: lengths,
                            forbidden: forbidden,
                            sunkRing: sunkRing,
                            components: components,
                            cellBias: cellBias)
        var occupancy = [Double](repeating: 0, count: Board.cellCount)
        var componentCounts = [Double](repeating: 0, count: components.count)
        var counted = 0

        for _ in 0..<chains {
            guard let chain = Chain(tables: tables, using: &generator) else { continue }
            for sweep in 0..<(burnIn + samples) {
                chain.sweep(using: &generator)
                guard sweep >= burnIn else { continue }
                chain.accumulate(into: &occupancy)
                componentCounts[chain.component] += 1
                counted += 1
            }
        }
        guard counted > 0 else { return nil }

        let scale = 1 / Double(counted)
        return Estimate(occupancy: occupancy.map { $0 * scale },
                        componentShare: componentCounts.map { $0 * scale })
    }

    /// The open cell most likely to hold a ship. RETURNS nil where `estimate`
    /// does.
    func peak<G: RandomNumberGenerator>(on board: Board, using generator: inout G) -> Coordinate? {
        guard let estimate = estimate(on: board, using: &generator) else { return nil }
        return board.shootableCells(excludingRingsAroundSunk: true)
            .max { estimate.occupancy[Self.index($0)] < estimate.occupancy[Self.index($1)] }
    }

    static func index(_ coordinate: Coordinate) -> Int {
        (coordinate.row - 1) * Board.size + coordinate.column - 1
    }

    // MARK: - Slots

    /// One on-board position of a ship as board indices.
    struct Slot {
        let cells: [Int]
        let ring: [Int]
    }

    /// Every on-board position for every ship length in the fleet.
    static let slots: [Int: [Slot]] = {
        var result: [Int: [Slot]] = [:]
        for length in Set(FleetLayout.deckCounts) {
            var list: [Slot] = []
            for orientation in Orientation.allCases {
                let maxRow = orientation == .vertical ? Board.size - length + 1 : Board.size
                let maxColumn = orientation == .horizontal ? Board.size - length + 1 : Board.size
                for row in 1...maxRow {
                    for column in 1...maxColumn {
                        let ship = ShipPlacement(length: length,
                                                 origin: Coordinate(row: row, column: column),
                                                 orientation: orientation)
                        list.append(Slot(cells: ship.cells.map(index), ring: ship.ring.map(index)))
                    }
                }
                if length == 1 { break }
            }
            result[length] = list
        }
        return result
    }()

    /// A number that changes whenever anything on the board does. Mixed with a
    /// per-match seed it makes the sampler's answer a function of the board,
    /// so asking twice about the same board gives the same shot.
    static func fingerprint(of board: Board) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325        // FNV-1a
        for coordinate in Board.allCoordinates {
            let value: UInt64
            switch board[coordinate] {
            case .water, .ship: value = 0
            case .miss: value = 1
            case .hit: value = 2
            case .sunk: value = 3
            }
            hash = (hash ^ value) &* 0x100_0000_01B3
        }
        return hash
    }

    /// The largest ring there is, a four-decker's in open water.
    private static let maxRing = 14

    // MARK: - The sampler

    // The inner loop runs a few hundred thousand times per shot. Written over
    // `Array` it took 5 ms in a release build and 190 ms in a debug one — the
    // build the app runs in when started from Xcode — because a debug build
    // checks and retains on every subscript. Hence plain buffers and `while`
    // loops below: they cost the same in both builds.

    /// Everything the chains share, flattened: every position of every ship
    /// still afloat that avoids the cells already ruled out, numbered one after
    /// another; ship `s` owns positions `firstSlot[s] ..< firstSlot[s + 1]`.
    private final class Tables {
        let shipCount: Int
        let componentCount: Int
        let maxSlots: Int
        let firstSlot: UnsafeMutablePointer<Int>
        let cellStart: UnsafeMutablePointer<Int>
        let cells: UnsafeMutablePointer<Int>
        let ringStart: UnsafeMutablePointer<Int>
        let rings: UnsafeMutablePointer<Int>
        /// The `cellBias` weight of each position, 1 without memory.
        let bias: UnsafeMutablePointer<Double>
        /// How many rings of sunk ships cover each cell (0 or 1).
        let sunkRing: UnsafeMutablePointer<Int>
        /// `exp(-strength × n)` per component, `maxRing + 1` entries each.
        let factors: UnsafeMutablePointer<Double>
        let strengths: UnsafeMutablePointer<Double>
        /// `log(prior) - logPartition` per component.
        let logBase: UnsafeMutablePointer<Double>

        init(lengths: [Int], forbidden: [Bool], sunkRing: [Int],
             components: [Component], cellBias: [Double]?) {
            var first = [0]
            var cellStart = [0], cells: [Int] = []
            var ringStart = [0], rings: [Int] = []
            var bias: [Double] = []
            for length in lengths {
                for slot in LayoutPosterior.slots[length]! where !slot.cells.contains(where: { forbidden[$0] }) {
                    cells += slot.cells
                    cellStart.append(cells.count)
                    rings += slot.ring
                    ringStart.append(rings.count)
                    bias.append(cellBias.map { weights in slot.cells.reduce(1) { $0 * weights[$1] } } ?? 1)
                }
                first.append(bias.count)
            }
            shipCount = lengths.count
            componentCount = components.count
            maxSlots = zip(first, first.dropFirst()).map { $1 - $0 }.max() ?? 0

            func buffer<T>(_ values: [T]) -> UnsafeMutablePointer<T> {
                let pointer = UnsafeMutablePointer<T>.allocate(capacity: max(1, values.count))
                pointer.initialize(from: values, count: values.count)
                return pointer
            }
            firstSlot = buffer(first)
            self.cellStart = buffer(cellStart)
            self.cells = buffer(cells)
            self.ringStart = buffer(ringStart)
            self.rings = buffer(rings)
            self.bias = buffer(bias)
            self.sunkRing = buffer(sunkRing)
            factors = buffer(components.flatMap { component in
                (0...LayoutPosterior.maxRing).map { exp(-component.strength * Double($0)) }
            })
            strengths = buffer(components.map(\.strength))
            logBase = buffer(components.map { log($0.prior) - $0.logPartition })
        }

        deinit {
            for pointer in [firstSlot, cellStart, cells, ringStart, rings, sunkRing] {
                pointer.deallocate()
            }
            for pointer in [bias, factors, strengths, logBase] {
                pointer.deallocate()
            }
        }
    }

    /// A fleet of the ships still afloat plus the hypothesis it is drawn
    /// under, updated one ship (or the hypothesis) at a time — Gibbs sampling,
    /// with the hypothesis as the tempering variable.
    private final class Chain {
        let tables: Tables
        private(set) var component: Int
        /// The position each ship is in.
        let placed: UnsafeMutablePointer<Int>
        /// How many afloat ships' cells-or-rings cover each cell.
        let footprint: UnsafeMutablePointer<Int>
        /// How many rings cover each cell, the sunk ships' included.
        let ringCover: UnsafeMutablePointer<Int>
        let order: UnsafeMutablePointer<Int>
        let candidates: UnsafeMutablePointer<Int>
        let weights: UnsafeMutablePointer<Double>

        /// RETURNS nil when no consistent fleet could be found to start from.
        init?<G: RandomNumberGenerator>(tables: Tables, using generator: inout G) {
            self.tables = tables
            component = Int.random(in: 0..<tables.componentCount, using: &generator)
            placed = .allocate(capacity: tables.shipCount)
            footprint = .allocate(capacity: Board.cellCount)
            ringCover = .allocate(capacity: Board.cellCount)
            order = .allocate(capacity: tables.shipCount)
            candidates = .allocate(capacity: max(1, tables.maxSlots))
            weights = .allocate(capacity: max(1, tables.maxSlots))
            var ship = 0
            while ship < tables.shipCount {
                order[ship] = ship
                ship += 1
            }

            // A consistent start: ships in random order, each uniform over
            // what is still free, the whole fleet redrawn if one does not fit.
            for _ in 0..<100 where start(using: &generator) { return }
            return nil
        }

        deinit {
            placed.deallocate()
            footprint.deallocate()
            ringCover.deallocate()
            order.deallocate()
            candidates.deallocate()
            weights.deallocate()
        }

        private func start<G: RandomNumberGenerator>(using generator: inout G) -> Bool {
            var cell = 0
            while cell < Board.cellCount {
                footprint[cell] = 0
                ringCover[cell] = tables.sunkRing[cell]
                cell += 1
            }
            shuffleOrder(using: &generator)
            var step = 0
            while step < tables.shipCount {
                let ship = order[step]
                var count = 0
                var slot = tables.firstSlot[ship]
                while slot < tables.firstSlot[ship + 1] {
                    if fits(slot) {
                        candidates[count] = slot
                        count += 1
                    }
                    slot += 1
                }
                guard count > 0 else { return false }
                let chosen = candidates[Int.random(in: 0..<count, using: &generator)]
                placed[ship] = chosen
                add(chosen)
                step += 1
            }
            return true
        }

        private func shuffleOrder<G: RandomNumberGenerator>(using generator: inout G) {
            var index = tables.shipCount - 1
            while index > 0 {
                let other = Int.random(in: 0...index, using: &generator)
                let held = order[index]
                order[index] = order[other]
                order[other] = held
                index -= 1
            }
        }

        private func fits(_ slot: Int) -> Bool {
            var index = tables.cellStart[slot]
            let end = tables.cellStart[slot + 1]
            while index < end {
                if footprint[tables.cells[index]] > 0 { return false }
                index += 1
            }
            return true
        }

        private func add(_ slot: Int) {
            var index = tables.cellStart[slot]
            var end = tables.cellStart[slot + 1]
            while index < end {
                footprint[tables.cells[index]] += 1
                index += 1
            }
            index = tables.ringStart[slot]
            end = tables.ringStart[slot + 1]
            while index < end {
                let cell = tables.rings[index]
                footprint[cell] += 1
                ringCover[cell] += 1
                index += 1
            }
        }

        private func remove(_ slot: Int) {
            var index = tables.cellStart[slot]
            var end = tables.cellStart[slot + 1]
            while index < end {
                footprint[tables.cells[index]] -= 1
                index += 1
            }
            index = tables.ringStart[slot]
            end = tables.ringStart[slot + 1]
            while index < end {
                let cell = tables.rings[index]
                footprint[cell] -= 1
                ringCover[cell] -= 1
                index += 1
            }
        }

        func sweep<G: RandomNumberGenerator>(using generator: inout G) {
            let factor = tables.factors + component * (LayoutPosterior.maxRing + 1)
            shuffleOrder(using: &generator)
            var step = 0
            while step < tables.shipCount {
                let ship = order[step]
                remove(placed[ship])
                var count = 0
                var total = 0.0
                var slot = tables.firstSlot[ship]
                let last = tables.firstSlot[ship + 1]
                while slot < last {
                    if fits(slot) {
                        var newlyGivenAway = 0
                        var index = tables.ringStart[slot]
                        let end = tables.ringStart[slot + 1]
                        while index < end {
                            if ringCover[tables.rings[index]] == 0 { newlyGivenAway += 1 }
                            index += 1
                        }
                        let weight = factor[newlyGivenAway] * tables.bias[slot]
                        candidates[count] = slot
                        weights[count] = weight
                        count += 1
                        total += weight
                    }
                    slot += 1
                }
                // The ship's own position always fits, so `count` is never 0.
                var remainder = Double.random(in: 0..<total, using: &generator)
                var chosen = candidates[count - 1]
                var pick = 0
                while pick < count {
                    remainder -= weights[pick]
                    if remainder < 0 {
                        chosen = candidates[pick]
                        break
                    }
                    pick += 1
                }
                placed[ship] = chosen
                add(chosen)
                step += 1
            }
            resampleComponent(using: &generator)
        }

        /// Draws the hypothesis given the fleet: prior × weight of this fleet's
        /// exposure under it ÷ that hypothesis's normaliser.
        private func resampleComponent<G: RandomNumberGenerator>(using generator: inout G) {
            var exposure = 0
            var cell = 0
            while cell < Board.cellCount {
                if ringCover[cell] > 0 { exposure += 1 }
                cell += 1
            }
            var logWeights = [Double](repeating: 0, count: tables.componentCount)
            for index in logWeights.indices {
                logWeights[index] = tables.logBase[index] - tables.strengths[index] * Double(exposure)
            }
            let top = logWeights.max() ?? 0
            let weights = logWeights.map { exp($0 - top) }
            var remainder = Double.random(in: 0..<weights.reduce(0, +), using: &generator)
            for (index, weight) in weights.enumerated() {
                remainder -= weight
                if remainder < 0 {
                    component = index
                    return
                }
            }
            component = weights.count - 1
        }

        func accumulate(into occupancy: inout [Double]) {
            occupancy.withUnsafeMutableBufferPointer { occupancy in
                var ship = 0
                while ship < tables.shipCount {
                    let slot = placed[ship]
                    var index = tables.cellStart[slot]
                    let end = tables.cellStart[slot + 1]
                    while index < end {
                        occupancy[tables.cells[index]] += 1
                        index += 1
                    }
                    ship += 1
                }
            }
        }
    }
}
