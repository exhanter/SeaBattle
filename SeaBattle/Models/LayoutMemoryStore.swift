//
//  LayoutMemoryStore.swift
//  SeaBattle
//
//  13.10: where the opt-in layout memory keeps the player's fleets — the last
//  `LayoutMemory.capacity` of them, on this device only. Written only while
//  `AppState.expertRemembersLayouts` is on, and only when a match against the
//  computer is played to the end: a fleet recorded at the start would be read
//  by the expert in the very match it belongs to.
//

import Foundation

enum LayoutMemoryStore {

    private static let key = "rememberedLayouts"

    static func layouts(in defaults: UserDefaults = .standard) -> [[ShipPlacement]] {
        guard let data = defaults.data(forKey: key),
              let layouts = try? JSONDecoder().decode([[ShipPlacement]].self, from: data) else {
            return []
        }
        return layouts
    }

    /// Adds a finished match's fleet, forgetting the oldest beyond capacity.
    /// A fleet that is not a legal standard one is not kept.
    static func remember(_ fleet: [ShipPlacement], in defaults: UserDefaults = .standard) {
        guard FleetLayout.isValid(fleet) else { return }
        let kept = Array((layouts(in: defaults) + [fleet]).suffix(LayoutMemory.capacity))
        guard let data = try? JSONEncoder().encode(kept) else { return }
        defaults.set(data, forKey: key)
    }

    static func forget(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
