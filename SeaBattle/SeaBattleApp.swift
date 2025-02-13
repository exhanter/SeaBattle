//
//  SeaBattleApp.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

@main
struct SeaBattleApp: App {
    @StateObject private var appState = AppState(tempInstance: false)
    var body: some Scene {
        WindowGroup {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadStartMenuView()
                    .environmentObject(appState)
                    .environment(\.locale, Locale(identifier: appState.language))
            } else {
                ContentView()
                    .environmentObject(appState)
                    .environment(\.locale, Locale(identifier: appState.language))
            }
        }
    }
}
