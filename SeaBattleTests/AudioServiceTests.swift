//
//  AudioServiceTests.swift
//  SeaBattleTests
//
//  The sound effects map onto bundled files. (This file used to be
//  `SeaBattleTests.swift` with the legacy `PlayerData` board tests too; those
//  went with the model on 30.10.)
//

import Foundation
import Testing
@testable import SeaBattle

@MainActor
struct AudioServiceTests {

    @Test("Every effect maps to a bundled sound file", arguments: AudioService.Effect.allCases)
    func effectFilesExist(_ effect: AudioService.Effect) {
        #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "") != nil)
    }

    @Test("Unknown sound names are ignored rather than crashing")
    func unknownNameIsIgnored() {
        // The old call sites pass raw file names, including "" on paths where
        // no sound was chosen.
        AudioService.shared.play(named: "")
        AudioService.shared.play(named: "not_a_real_file.wav")
    }
}
