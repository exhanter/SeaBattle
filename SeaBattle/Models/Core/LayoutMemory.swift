//
//  LayoutMemory.swift
//  SeaBattle
//
//  13.10: the opt-in "the expert remembers how I arrange my fleet". Off by
//  default — without it the expert reads only the board of the current match
//  (`LayoutPosterior.standard`). With it, the fleets the player arranged in
//  earlier matches against the computer shape what the expert expects before
//  the first shot, in two ways:
//
//  - how hard this player hides: each remembered fleet's exposure is evidence
//    for or against each hiding strength, so a player who always packs the
//    fleet against the edges starts the match already suspected of it;
//  - where this player likes to put ships: cells that held a ship in many
//    remembered fleets weigh more, so a habit — the four-decker always along
//    the bottom edge — is looked for first.
//
//  Both are deliberately soft. The fleets in memory are few, and a player who
//  changes style should not be chased with a confident wrong guess, so the
//  evidence is damped and a share of the ordinary prior always stays.
//

import Foundation

enum LayoutMemory {

    /// How many fleets are kept; older ones are forgotten first.
    static let capacity = 30

    /// Below this many fleets the habits are not read at all — two or three
    /// fleets say nothing a random layout would not.
    static let minimumForHabits = 5

    /// The expert's prior for a player whose earlier fleets were `layouts`.
    static func posterior(remembering layouts: [[ShipPlacement]]) -> LayoutPosterior {
        let standard = LayoutPosterior.standard
        guard !layouts.isEmpty else { return standard }
        let recent = Array(layouts.suffix(capacity))

        // How hard this player hides. Each fleet is a draw from one of the
        // hypotheses; the evidence is damped (×0.5) because no real player
        // arranges by exactly this formula, and a fifth of the ordinary
        // prior is kept so the board of the match can still overrule it.
        let exposures = recent.map { Double(FleetLayout.ringExposure(of: $0)) }
        let logEvidence = standard.components.map { component in
            exposures.reduce(log(component.prior)) { sum, exposure in
                sum + 0.5 * (-component.strength * exposure - component.logPartition)
            }
        }
        let top = logEvidence.max() ?? 0
        let learned = logEvidence.map { exp($0 - top) }
        let learnedTotal = learned.reduce(0, +)
        let components = zip(standard.components, learned).map { component, weight in
            LayoutPosterior.Component(strength: component.strength,
                                      prior: 0.8 * weight / learnedTotal + 0.2 * component.prior,
                                      logPartition: component.logPartition)
        }

        var posterior = LayoutPosterior(components: components)
        if recent.count >= minimumForHabits {
            posterior.cellBias = habits(in: recent)
        }
        return posterior
    }

    /// For every board index, how much more (or less) often this player has
    /// put a ship there than the 20 in 100 an average cell gets, smoothed
    /// towards "average" by `pseudoFleets` imaginary average fleets.
    ///
    /// 30 is measured (13.10): with 6, twenty auto-arranged fleets left
    /// enough noise to look like habits and cost the expert most of a shot
    /// against a player with none; with 30 that is gone and a player with
    /// habits still loses 0.4–2.3 shots a match to them.
    static func habits(in layouts: [[ShipPlacement]], pseudoFleets: Double = 30) -> [Double] {
        let average = Double(FleetLayout.occupiedCellCount) / Double(Board.cellCount)
        var counts = [Double](repeating: 0, count: Board.cellCount)
        for layout in layouts {
            for ship in layout {
                for cell in ship.cells where cell.isOnBoard {
                    counts[LayoutPosterior.index(cell)] += 1
                }
            }
        }
        let fleets = Double(layouts.count)
        return counts.map { count in
            (count + pseudoFleets * average) / (fleets + pseudoFleets) / average
        }
    }
}
