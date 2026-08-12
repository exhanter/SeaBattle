//
//  SeaBattleApp.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

@main
struct SeaBattleApp: App {
    @State private var appState = AppState()
    var body: some Scene {
        WindowGroup {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadStartMenuView()
                    .environment(appState)
                    .environment(\.locale, Locale(identifier: appState.language))
            } else {
                ContentView()
                    .environment(appState)
                    .environment(\.locale, Locale(identifier: appState.language))
            }
        }
    }
}
