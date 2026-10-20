//
//  ExpertInferenceTests.swift
//  SeaBattleTests
//
//  13.10: the expert stopped assuming a random fleet. On that day the player
//  beat it ten times out of ten by packing the fleet against the edges and
//  against each other; the heat map it used looked for ships everywhere but
//  there. `LayoutPosterior` samples whole fleets instead and reads from the
//  board how hidden they are likely to be; `LayoutMemory` is the opt-in that
//  also reads the player's earlier fleets.
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct ExpertInferenceTests {

    /// A tracked board with these ships sunk and nothing else known.
    private func board(sunk ships: [ShipPlacement]) -> Board {
        var board = Board()
        for ship in ships {
            for cell in ship.cells { board.mark(.sunk, at: cell) }
        }
        return board
    }

    private func ship(_ length: Int, _ row: Int, _ column: Int) -> ShipPlacement {
        ShipPlacement(length: length, origin: Coordinate(row: row, column: column), orientation: .horizontal)
    }

    /// Four ships against the top edge, their rings overlapping — the way the
    /// player hid on 13.10.
    private var packedBoard: Board {
        board(sunk: [ship(4, 1, 1), ship(3, 3, 1), ship(3, 1, 6), ship(2, 3, 5)])
    }

    /// The same four ships out in open water, each with its own ring.
    private var openBoard: Board {
        board(sunk: [ship(4, 5, 3), ship(3, 8, 3), ship(3, 2, 4), ship(2, 8, 8)])
    }

    /// The share of the sampling that went to hypotheses of real hiding.
    private func hiddenShare(on board: Board, posterior: LayoutPosterior = .standard) -> Double {
        var generator = SeededGenerator(seed: 1)
        let estimate = posterior.estimate(on: board, using: &generator)!
        return zip(posterior.components, estimate.componentShare)
            .filter { $0.0.strength >= 0.6 }
            .map(\.1)
            .reduce(0, +)
    }

    @Test("Sunk ships packed against the edge make the expert suspect a hidden fleet")
    func packedShipsPointToHiding() {
        let packed = hiddenShare(on: packedBoard)
        let open = hiddenShare(on: openBoard)
        let prior = LayoutPosterior.standard.components
            .filter { $0.strength >= 0.6 }
            .map(\.prior)
            .reduce(0, +)
        #expect(packed > prior, "packed \(packed), prior \(prior)")
        #expect(open < prior, "open \(open), prior \(prior)")
        #expect(packed > open + 0.3, "packed \(packed), open \(open)")
    }

    @Test("Hiding is suspected only once the sunk ships show it")
    func hidingNeedsEvidence() {
        // 14.10: before this the expert reckoned with hiding from the first
        // shot. Now the board has to show it first.
        #expect(LayoutPosterior.showsHiding(on: packedBoard))
        #expect(!LayoutPosterior.showsHiding(on: openBoard))
        #expect(!LayoutPosterior.showsHiding(on: Board()))
        // One ship, even in a corner, is never enough.
        #expect(!LayoutPosterior.showsHiding(on: board(sunk: [ship(4, 1, 1)])))
        // Two in corners are: 8 + 7 cells of water kept back.
        let corners = board(sunk: [ship(4, 1, 1), ship(3, 10, 8)])
        #expect(LayoutPosterior.savedWater(on: corners) == 15)
        #expect(LayoutPosterior.showsHiding(on: corners))
        // Two in open water are not.
        let apart = board(sunk: [ship(4, 3, 3), ship(3, 7, 4)])
        #expect(LayoutPosterior.savedWater(on: apart) == 0)
        #expect(!LayoutPosterior.showsHiding(on: apart))
    }

    @Test("A fleet kept off the edges no longer beats the expert")
    func fleetOffTheEdgesIsFound() {
        // 14.10: while the expert reckoned with hiding from the first shot it
        // swept the edges first, and a fleet with no ship on an edge took it
        // 54 shots (simulator, 800 fleets) — the old heat map needed 49. Now
        // about 49.5.
        var generator = SeededGenerator(seed: 7)
        var total = 0
        let matches = 16
        for match in 0..<matches {
            var target = Board(ships: offTheEdges(using: &generator))
            var shots = 0
            while !target.isFleetDestroyed, shots < Board.cellCount {
                let view = target.opponentView()
                target.apply(shotAt: ComputerOpponent.candidates(for: .expert, on: view, seed: UInt64(match))[0])
                shots += 1
            }
            total += shots
        }
        let average = Double(total) / Double(matches)
        print(String(format: "Expert against fleets off the edges: %.1f shots", average))
        #expect(average < 53)
    }

    /// A legal fleet with no ship touching an edge: ships one at a time, each
    /// uniform over what is still free in the inner 8 × 8.
    private func offTheEdges(using generator: inout SeededGenerator) -> [ShipPlacement] {
        while true {
            var fleet: [ShipPlacement] = []
            for length in FleetLayout.deckCounts {
                var spots: [ShipPlacement] = []
                for orientation in Orientation.allCases {
                    for row in 2...9 {
                        for column in 2...9 {
                            let candidate = ShipPlacement(length: length,
                                                          origin: Coordinate(row: row, column: column),
                                                          orientation: orientation)
                            guard candidate.cells.allSatisfy({ (2...9).contains($0.row) && (2...9).contains($0.column) }),
                                  FleetLayout.conflicts(in: fleet + [candidate]).isEmpty else { continue }
                            spots.append(candidate)
                        }
                    }
                }
                guard let spot = spots.randomElement(using: &generator) else { break }
                fleet.append(spot)
            }
            if fleet.count == FleetLayout.shipCount { return fleet }
        }
    }

    @Test("Nothing is expected where no ship can be")
    func occupancyRespectsTheRules() {
        var board = packedBoard
        board.mark(.miss, at: Coordinate(row: 6, column: 6))
        var generator = SeededGenerator(seed: 2)
        let estimate = LayoutPosterior.standard.estimate(on: board, using: &generator)!
        let open = Set(board.shootableCells(excludingRingsAroundSunk: true))
        for coordinate in Board.allCoordinates where !open.contains(coordinate) {
            #expect(estimate.occupancy[LayoutPosterior.index(coordinate)] == 0, "\(coordinate)")
        }
        // Six ships are still afloat — 2 + 2 + 1 + 1 + 1 + 1 cells.
        #expect(abs(estimate.occupancy.reduce(0, +) - 8) < 1e-9)
    }

    @Test("Before any shot the hypotheses keep their prior weights")
    func emptyBoardKeepsThePrior() {
        // `logPartition` is what keeps a strong hypothesis from winning on an
        // empty board just because its weights are small numbers. If it were
        // off, the shares here would drift far from the prior.
        var generator = SeededGenerator(seed: 3)
        let posterior = LayoutPosterior(components: LayoutPosterior.standard.components,
                                        chains: 16, burnIn: 20, samples: 200)
        let estimate = posterior.estimate(on: Board(), using: &generator)!
        for (component, share) in zip(posterior.components, estimate.componentShare) {
            #expect(abs(share - component.prior) < 0.08,
                    "strength \(component.strength): \(share) against \(component.prior)")
        }
    }

    @Test("The same board and seed give the same shot")
    func decisionsAreReproducible() {
        let board = openBoard
        let first = ComputerOpponent.candidates(for: .expert, on: board, seed: 42)
        let second = ComputerOpponent.candidates(for: .expert, on: board, seed: 42)
        #expect(first == second)
        #expect(first.count == 1)
    }

    @Test("A fleet packed against the edges no longer beats the expert")
    func packedFleetIsFound() async {
        // Measured outside the app (13.10, 600 fleets): against fleets hidden
        // at strength 1, the heat map needed 71.7 shots and won 6% of matches
        // against the best shooting the app has; the sampler needs 37.7 and
        // wins 94%. Since 14.10 it waits for the sunk ships to show the hiding
        // and needs 42 (89%). A random fleet takes about 55.
        var generator = SeededGenerator(seed: 4)
        var total = 0
        let matches = 12
        for match in 0..<matches {
            let fleet = FleetLayout.hiddenArrangement(strength: 1, passes: 60, using: &generator)
            var target = Board(ships: fleet)
            var shots = 0
            while !target.isFleetDestroyed, shots < Board.cellCount {
                let view = target.opponentView()
                let shot = ComputerOpponent.candidates(for: .expert, on: view, seed: UInt64(match))[0]
                target.apply(shotAt: shot)
                shots += 1
            }
            total += shots
        }
        let average = Double(total) / Double(matches)
        print(String(format: "Expert against fleets hidden at strength 1: %.1f shots", average))
        #expect(average < 50)
    }

    // MARK: - The opt-in memory

    @Test("Without remembered fleets the memory changes nothing")
    func emptyMemoryIsTheStandardPrior() {
        let posterior = LayoutMemory.posterior(remembering: [])
        #expect(posterior.components == LayoutPosterior.standard.components)
        #expect(posterior.cellBias == nil)
    }

    @Test("A player who always hides starts the match suspected of it")
    func rememberedHidingRaisesThePrior() {
        var generator = SeededGenerator(seed: 5)
        let hidden = (0..<10).map { _ in
            FleetLayout.hiddenArrangement(strength: 1, passes: 60, using: &generator)
        }
        let random = (0..<10).map { _ in FleetLayout.random(using: &generator) }
        func hiddenPrior(_ posterior: LayoutPosterior) -> Double {
            posterior.components.filter { $0.strength >= 0.6 }.map(\.prior).reduce(0, +)
        }
        let standard = hiddenPrior(.standard)
        #expect(hiddenPrior(LayoutMemory.posterior(remembering: hidden)) > standard + 0.3)
        #expect(hiddenPrior(LayoutMemory.posterior(remembering: random)) < standard)
        // A fifth of the ordinary prior always stays, so the board of the
        // match can still overrule the memory.
        for component in LayoutMemory.posterior(remembering: hidden).components {
            let ordinary = LayoutPosterior.standard.components.first { $0.strength == component.strength }!
            #expect(component.prior >= 0.2 * ordinary.prior - 1e-12)
        }
    }

    @Test("Habits are read only from enough fleets, and softly")
    func habitsAreSmoothed() {
        let same = Array(repeating: FleetLayout.canonicalLayout(), count: LayoutMemory.minimumForHabits - 1)
        #expect(LayoutMemory.posterior(remembering: same).cellBias == nil)

        let many = Array(repeating: FleetLayout.canonicalLayout(), count: 20)
        let bias = LayoutMemory.posterior(remembering: many).cellBias!
        let always = LayoutPosterior.index(Coordinate(row: 1, column: 1))
        let never = LayoutPosterior.index(Coordinate(row: 10, column: 10))
        #expect(bias[always] > 1.5)
        #expect(bias[never] < 1 && bias[never] > 0)
    }

    @Test("The store keeps the latest fleets, only legal ones, and forgets on request")
    func storeKeepsRecentFleets() {
        let defaults = UserDefaults(suiteName: "ExpertInferenceTests")!
        LayoutMemoryStore.forget(in: defaults)
        #expect(LayoutMemoryStore.layouts(in: defaults).isEmpty)

        var generator = SeededGenerator(seed: 6)
        var fleets: [[ShipPlacement]] = []
        for _ in 0..<(LayoutMemory.capacity + 3) {
            let fleet = FleetLayout.random(using: &generator)
            fleets.append(fleet)
            LayoutMemoryStore.remember(fleet, in: defaults)
        }
        LayoutMemoryStore.remember(Array(fleets[0].prefix(3)), in: defaults)

        let kept = LayoutMemoryStore.layouts(in: defaults)
        #expect(kept.count == LayoutMemory.capacity)
        #expect(kept == Array(fleets.suffix(LayoutMemory.capacity)))

        LayoutMemoryStore.forget(in: defaults)
        #expect(LayoutMemoryStore.layouts(in: defaults).isEmpty)
        defaults.removePersistentDomain(forName: "ExpertInferenceTests")
    }

    @Test("Turning the option off erases the memory")
    func switchingOffForgets() {
        let appState = AppState()
        let previous = appState.expertRemembersLayouts
        appState.expertRemembersLayouts = true
        LayoutMemoryStore.remember(FleetLayout.canonicalLayout())
        #expect(!LayoutMemoryStore.layouts().isEmpty)

        appState.expertRemembersLayouts = false
        #expect(LayoutMemoryStore.layouts().isEmpty)
        #expect(!AppState().expertRemembersLayouts, "Off is what a fresh AppState reads back")
        appState.expertRemembersLayouts = previous
    }
}
