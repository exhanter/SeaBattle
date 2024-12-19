//
//  Ship.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import SwiftUI
struct Ship {
    enum Orientation {
        case horizontal, vertical, both
    }
    let id = UUID()
    let number: Int
    var orientation: Orientation
    var numberOfDecks: Int
    var isDestroyed = false
    var coordinates: [(Int, Int)]
    init(number: Int, orientation: Orientation, numberOfDecks: Int, isDestroyed: Bool = false, coordinates: [(Int, Int)]) {
        self.number = number
        self.orientation = orientation
        self.numberOfDecks = numberOfDecks
        self.isDestroyed = isDestroyed
        self.coordinates = coordinates
    }
}
