//
//  Ship.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import SwiftUI
struct Ship: Codable, Identifiable {
    enum Orientation: String, Codable {
        case horizontal, vertical
    }
    let id: UUID
    let number: Int
    var orientation: Orientation
    let numberOfDecks: Int
    var isDestroyed = false
    var coordinates: [(Int, Int)]
    init(number: Int, orientation: Orientation, numberOfDecks: Int, isDestroyed: Bool = false, coordinates: [(Int, Int)], id: UUID = UUID()) {
        self.id = id
        self.number = number
        self.orientation = orientation
        self.numberOfDecks = numberOfDecks
        self.isDestroyed = isDestroyed
        self.coordinates = coordinates
    }

    // MARK: - Codable

    // Custom coding maps the legacy `[(Int, Int)]` coordinates to `[Coordinate]`,
    // since tuples are not Codable. Once the engine is migrated to `Coordinate`
    // this can collapse to synthesized conformance.
    private enum CodingKeys: String, CodingKey {
        case id, number, orientation, numberOfDecks, isDestroyed, coordinates
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCoordinates = try container.decode([Coordinate].self, forKey: .coordinates)
        self.init(
            number: try container.decode(Int.self, forKey: .number),
            orientation: try container.decode(Orientation.self, forKey: .orientation),
            numberOfDecks: try container.decode(Int.self, forKey: .numberOfDecks),
            isDestroyed: try container.decode(Bool.self, forKey: .isDestroyed),
            coordinates: decodedCoordinates.map { $0.tuple },
            id: try container.decode(UUID.self, forKey: .id)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(numberOfDecks, forKey: .numberOfDecks)
        try container.encode(isDestroyed, forKey: .isDestroyed)
        try container.encode(coordinates.map(Coordinate.init), forKey: .coordinates)
    }
}
